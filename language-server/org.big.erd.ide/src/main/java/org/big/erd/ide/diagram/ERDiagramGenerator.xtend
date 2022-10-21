package org.big.erd.ide.diagram

import com.google.inject.Inject
import org.big.erd.entityRelationship.Entity
import org.big.erd.entityRelationship.Attribute
import org.big.erd.entityRelationship.AttributeType
import org.big.erd.entityRelationship.EntityRelationshipPackage
import org.big.erd.entityRelationship.Relationship
import org.big.erd.entityRelationship.RelationEntity
import org.big.erd.entityRelationship.Model
import org.big.erd.ide.diagram.EntityNode
import org.big.erd.ide.diagram.NotationEdge
import org.big.erd.ide.diagram.ERModel
import org.eclipse.emf.ecore.EObject
import org.eclipse.sprotty.SEdge
import org.eclipse.sprotty.SModelElement
import org.eclipse.sprotty.SButton
import org.eclipse.sprotty.LayoutOptions
import org.eclipse.sprotty.SLabel
import java.util.ArrayList
import java.util.List
import org.eclipse.sprotty.xtext.IDiagramGenerator
import org.apache.log4j.Logger
import org.eclipse.sprotty.IDiagramState
import org.eclipse.sprotty.xtext.tracing.ITraceProvider
import org.eclipse.sprotty.xtext.SIssueMarkerDecorator
import org.eclipse.sprotty.SCompartment
import org.big.erd.entityRelationship.CardinalityType
import org.big.erd.entityRelationship.NotationType
import org.big.erd.entityRelationship.GenerateOptionType

import static org.big.erd.entityRelationship.EntityRelationshipPackage.Literals.*


class ERDiagramGenerator implements IDiagramGenerator {

	static val LOG = Logger.getLogger(ERDiagramGenerator)

	@Inject extension ITraceProvider
	@Inject extension SIssueMarkerDecorator

	IDiagramState state
	Model model
	List<Entity> extendedEntities

	override generate(Context context) {
		this.state = context.state
		val contentHead = context.resource.contents.head
		if (contentHead instanceof Model) {
			LOG.debug("Generating diagram for model with URI '" + context.resource.URI.lastSegment + "'")
			model = contentHead
			toSGraph(contentHead, context)
		}
	}

	def ERModel toSGraph(Model m, extension Context context) {
		val genOption = m.generateOption?.generateOptionType ?: GenerateOptionType.OFF
		val notationType = m.notation?.notationType ?: NotationType.DEFAULT
		val graph = new ERModel => [
			id = idCache.uniqueId(m, 'root')
			type = DiagramTypes.GRAPH
			name = m.name
			notation = notationType.toString
			generateType = genOption !== null ? genOption.toString : 'off'
			children = new ArrayList<SModelElement>
		]

		// Create entity nodes and inheritance edges
		extendedEntities = new ArrayList<Entity>
		graph.children.addAll(m.entities.map[toSNode(context)])
		graph.children.addAll(extendedEntities.map[inheritanceEdges(context)])
		
		// Create relationship nodes and edges
		m.relationships.forEach[
			graph.children.add(relationshipNodes(it, context))
			graph.children.addAll(addRelationEdges(it, context))
		]
		graph.traceAndMark(m, context)
		return graph;
	}

	def RelationshipNode relationshipNodes(Relationship relationship, extension Context context) {
		val relationshipId = idCache.uniqueId(relationship, relationship.name)
		return (new RelationshipNode [
			id = relationshipId
			type = DiagramTypes.NODE_RELATIONSHIP
			weak = relationship.weak ? true : false
			layout = 'vbox'
			layoutOptions = new LayoutOptions [
				paddingFactor = 2.0
			]
			children = #[
				(new SLabel [
					id = idCache.uniqueId(relationshipId + '.label')
					text = relationship.name
					type = 'label:relationship'
				]).trace(relationship, RELATIONSHIP__NAME, -1)
			]
		]).traceAndMark(relationship, context)
	}
	
	def List<NotationEdge> addRelationEdges(Relationship relationship, extension Context context) {
		val edges = new ArrayList<NotationEdge>
		
		// for each RelationEntity create an edge that connects the entity with the relationship node
		if (relationship.first !== null) {
			val source = idCache.getId(relationship.first.target)
			val target = idCache.getId(relationship)
			edges.add(createEdgeAndAddToGraph(relationship.first, source, target, context))
		}
		
		if (relationship.second !== null) {
			val source = idCache.getId(relationship)
			val target = idCache.getId(relationship.second.target)
			edges.add(createEdgeAndAddToGraph(relationship.second, source, target, context))
		}
		
		if (relationship.third !== null) {
			val source = idCache.getId(relationship)
			val target = idCache.getId(relationship.third.target)
			edges.add(createEdgeAndAddToGraph(relationship.third, source, target, context))
		}
		
		return edges
	}

	def NotationEdge createEdgeAndAddToGraph(RelationEntity relationEntity, String source, String target, extension Context context) {
		val notationType = model.notation?.notationType ?: NotationType.DEFAULT
		val relationship = relationEntity.eContainer() as Relationship;
		val edgeId = idCache.uniqueId(relationEntity, source + ":" + relationship.name + ":" + target)
		val cardinality = getCardinality(relationEntity)
		return (new NotationEdge [
			id = edgeId
			type = getEdgeType(relationEntity, notationType)
			sourceId = source
			targetId = target
			notation = notationType.toString
			connectivity = cardinality
			isSource = relationEntity.equals(relationship.first)
			children = #[
				(new SLabel [
					id = idCache.uniqueId(edgeId + '.label')
					text = getEdgeLabelText(notationType, cardinality)
					type = DiagramTypes.LABEL_TOP
				]).trace(relationEntity, RELATION_ENTITY__CARDINALITY, -1),
				(new SLabel [
					id = idCache.uniqueId(edgeId + '.roleLabel')
					text = getRoleLabelText(relationEntity)
					type = DiagramTypes.LABEL_BOTTOM
				]).trace(relationEntity, RELATION_ENTITY__ROLE, -1)
			]
		]).traceAndMark(relationEntity, context)
	}

	def EntityNode toSNode(Entity e, extension Context context) {
		if (e.extends !== null) {
			this.extendedEntities.add(e)
		}
		
		val entityId = idCache.uniqueId(e, e.name)
		val node = new EntityNode [
			id = entityId
			type = DiagramTypes.NODE_ENTITY
			weak = e.weak ? true : false
			layout = 'vbox'
			layoutOptions = new LayoutOptions [
				VGap = 10.0
			]
			children = new ArrayList<SModelElement>
		]

		// Header with label and collapse/expand button
		node.children.add(new SCompartment => [
			id = idCache.uniqueId(entityId + '.header-comp')
			type = DiagramTypes.COMP_ENTITY_HEADER
			layout = 'hbox'
			children = #[
				(new SLabel [
					id = idCache.uniqueId(entityId + '.label')
					type = DiagramTypes.ENTITY_LABEL
					text = e.name
				]).trace(e, EntityRelationshipPackage.Literals.ENTITY__NAME, -1),
				(new SButton [
					id = idCache.uniqueId(entityId + '.button')
					type = DiagramTypes.BUTTON_EXPAND
				])
			]
		])

		// Create attributes if element is expanded
		if (state.expandedElements.contains(entityId) || state.currentModel.type == 'NONE') {
			val comp = new SCompartment => [
				id = entityId + '.attributes'
				type = DiagramTypes.COMP_ATTRIBUTES
				layout = 'vbox'
				layoutOptions = new LayoutOptions [
					HAlign = 'left'
					VGap = 1.0
				]
				children = new ArrayList<SModelElement>
			]
			comp.children.addAll(e.attributes.map[createAttributeLabels(entityId, context)])
			node.children.add(comp)
			state.expandedElements.add(entityId)
			node.expanded = true
		} else {
			node.expanded = false
		}
		node.traceAndMark(e, context)
		return node
	}

	def SCompartment createAttributeLabels(Attribute a, String entityId, extension Context context) {
		val attributeId = idCache.uniqueId(a, entityId + '.' + a.name)
		val labelType = getAttributeLabelType(a)
		return (new SCompartment => [
			id = attributeId
			type = DiagramTypes.COMP_ATTRIBUTE_ROW
			layout = 'hbox'
			layoutOptions = new LayoutOptions [
				VAlign = 'middle'
				HGap = 5.0
			]
			children = #[
				(new SLabel [
					id = attributeId + '.name'
					text = a.name
					type = labelType
				]).trace(a, ATTRIBUTE__NAME, -1),
				(new SLabel [
					id = attributeId + ".datatype"
					text = attributeDatatypeString(a)
					type = labelType
				])
			]
		]).traceAndMark(a, context)
	}

	def SEdge inheritanceEdges(Entity entity, extension Context context) {
		return new SEdge [
			sourceId = idCache.getId(entity)
			targetId = idCache.getId(entity.extends)
			id = idCache.uniqueId(entity + sourceId + ':extends:' + targetId)
			type = DiagramTypes.EDGE_INHERITANCE
			children = new ArrayList<SModelElement>
		]
	}
	
	def <T extends SModelElement> T traceAndMark(T sElement, EObject element, Context context) {
		return sElement.trace(element).addIssueMarkers(element, context)
	}

	def String attributeDatatypeString(Attribute a) {
		if (a.datatype !== null) {
			if (a.datatype.size != 0) {
				return a.datatype.type + '(' + a.datatype.size + ')'
			}
			return a.datatype.type
		}
		return ' '
	}
	
	def String getCardinality(RelationEntity relationEntity) {
		if (relationEntity.cardinality !== null && !(relationEntity.cardinality.equals(CardinalityType.NONE))) {
			return relationEntity.cardinality.toString
		}
		return ' '
	}
	
	def getEdgeType(RelationEntity relation, NotationType notation) {
		if (notation.equals(NotationType.CHEN)) {
			val cardinality = relation.cardinality ?: CardinalityType.NONE
			if (cardinality === CardinalityType.ZERO_OR_ONE || cardinality === CardinalityType.ZERO_OR_MORE) {
				return DiagramTypes.EDGE_PARTIAL
			}
		}
		return DiagramTypes.EDGE
	}
	
	def String getEdgeLabelText(NotationType notation, String cardinality) {
		if (notation.equals(NotationType.CROWSFOOT) || notation.equals(NotationType.BACHMAN)) {
			return ' '
		}
		return cardinality
	}
	
	def String getRoleLabelText(RelationEntity relation) {
		if (relation.role !== null) {
			return relation.role
		} 
		return ' '
	}
	
	def String getAttributeLabelType(Attribute attribute) {
		return switch attribute.type {
			case AttributeType.KEY: DiagramTypes.LABEL_KEY
			case AttributeType.PARTIAL_KEY: DiagramTypes.LABEL_PARTIAL_KEY
			case AttributeType.DERIVED: DiagramTypes.LABEL_DERIVED
			default: DiagramTypes.LABEL_TEXT
		}
	}
}
