/*
 * generated by Xtext 2.24.0
 */
package org.big.erd.validation

import org.big.erd.entityRelationship.Model
import org.big.erd.entityRelationship.EntityRelationshipPackage
import org.eclipse.xtext.validation.Check
import org.big.erd.entityRelationship.CardinalityType
import org.big.erd.entityRelationship.RelationEntity
import org.big.erd.entityRelationship.Relationship
import org.big.erd.entityRelationship.NotationType
import org.eclipse.xtext.validation.ComposedChecks
import org.big.erd.entityRelationship.Entity
import org.big.erd.entityRelationship.AttributeType

/**
 * Custom ValidationRules with composed checks 
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation for documentation
 */
@ComposedChecks(validators=#[
	NamingValidator
])
class EntityRelationshipValidator extends AbstractEntityRelationshipValidator {

	@Check
	def checkKeys(Entity entity) {
		if (entity.weak) {
			if (entity.attributes?.filter[it.type === AttributeType.PARTIAL_KEY].isNullOrEmpty) {
				info('''Missing partial key for weak entity''', entity, EntityRelationshipPackage.Literals.ENTITY__NAME)
			}
		} else {
			if (entity.attributes?.filter[it.type === AttributeType.KEY].isNullOrEmpty) {
				info('''Missing primary key for entity''', entity, EntityRelationshipPackage.Literals.ENTITY__NAME)
			}
		}
	}
	
	@Check
	def checkRelationEntity(RelationEntity relation) {
		val model = relation.eContainer.eContainer
		if (model instanceof Model) {
			val notation = model.notation?.notationType
			if (notation !== null) {
				if (notation.equals(NotationType.BACHMAN) ||
					notation.equals(NotationType.CHEN) ||
					notation.equals(NotationType.CROWSFOOT)
				) {
					checkCardinality(relation)
				}
			}
		}
	}
	
	def checkCardinality(RelationEntity relation) {
		switch relation.cardinality {
    		case CardinalityType.ZERO_OR_ONE,
    		case CardinalityType.ZERO_OR_MORE,
    		case CardinalityType.ONE,
    		case CardinalityType.MANY: return
    		default: info('''Invalid cardinality for '«relation.target.name»'!«'\n\n'»Use [0..1], [0..N], [1] or [N]''', relation, EntityRelationshipPackage.Literals.RELATION_ENTITY__CARDINALITY)
    	}
	}
  	
  	def featureOf(RelationEntity relation) {
  		val r = relation.eContainer as Relationship
  		if (r.first === relation) {
  			return EntityRelationshipPackage.Literals.RELATIONSHIP__FIRST
  		} else if (r.second === relation) {
  			return EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND
  		} else {
  			return EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD
  		}
  	}

  	/* 
  	@Check
	def checkCardinality(Model model) {
		val notation = model.notation?.notationType !== null ? model.notation.notationType : NotationType.DEFAULT
		if (notation.equals(NotationType.CROWSFOOT)) {
			val ternaryRelationships = model.relationships.filter[it.third !== null]
			if (!ternaryRelationships.empty) {
				ternaryRelationships.forEach[r |
					error('''Ternary Relationships are not allowed for Crow's Foot Notation!''', r, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				]
			}
		}
    }*/
    
    /* 
	def checkUmlCardinality(RelationEntity relationEntity, Relationship relationship, EStructuralFeature feature) {
		if (relationEntity !== null) {
			if(relationEntity.customMultiplicity !== null || relationEntity.minMax !== null ||
			  (relationEntity.uml === null && relationEntity.cardinality !== CardinalityType.ZERO && 
			  relationEntity.cardinality !== CardinalityType.ONE)){
				info('''Wrong cardinality.Usage: [num],[min..max] or [min..*]''', relationship, feature)
			}
			if(relationEntity.uml.contains("comp") && relationEntity.uml.contains("agg")){
				info('''Invalid aggregation. Use comp or agg''', relationship, feature)
			}
			if (relationEntity.uml.contains("..")) {
				var cardinality = relationEntity.uml
				
				if(relationEntity.uml.contains(" ")){
					// remove type (agg|comp)
					cardinality = relationEntity.uml.split(" ").get(1)
				}
				var numbers = cardinality.split("\\.\\.")
				if(numbers.length <= 1){
					info('''Wrong cardinality. Usage: [min..max] min <= max''', relationship, feature)
				}
				if(numbers.length === 2){
					if(numbers.get(0).isEmpty || numbers.get(1).isEmpty){
						info('''Wrong cardinality. Usage: [min..max] min <= max''', relationship, feature)
					}
					var n1 = numbers.get(0)
					var n2 = numbers.get(1)
					if (n1.matches("\\d+") && n2.matches("\\d+") && Integer.parseInt(n1) > Integer.parseInt(n2)) {
						info('''Wrong cardinality. Usage: [min..max] min <= max''', relationship, feature)
					}
				}
			}
		}
	}
	
	def checkNoMultipleAggregation(Relationship relationship){
		val firstElement = relationship.first
		val secondElement = relationship.second
		val thirdElement = relationship.third
		var aggregationCounter = 0;
		
		if (firstElement !== null) {
			if (firstElement.uml.contains("agg") || firstElement.uml.contains("comp")) {
				aggregationCounter++;
			}
		}
		if (secondElement !== null ) {
			if(secondElement.uml.contains("agg") || secondElement.uml.contains("comp")) {
				aggregationCounter++;
				if(aggregationCounter > 1){
					info('''No multiple aggregation possible.''', relationship, EntityRelationshipPackage.Literals.RELATIONSHIP__SECOND)
				}
			}
		}
		if (thirdElement !== null) {
			if (thirdElement.uml.contains("agg") || thirdElement.uml.contains("comp")) {
				aggregationCounter++;
				if (aggregationCounter > 1) {
					info('''No multiple aggregation possible.''', relationship, EntityRelationshipPackage.Literals.RELATIONSHIP__THIRD)
				}
			}
		}
	}
	*/
	
}
