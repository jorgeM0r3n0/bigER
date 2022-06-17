/*
 * generated by Xtext 2.24.0
 */
package org.big.erd.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.big.erd.entityRelationship.Attribute
import org.big.erd.entityRelationship.Model
import org.big.erd.entityRelationship.Entity
import org.big.erd.entityRelationship.DataType
import org.big.erd.entityRelationship.AttributeType
import org.big.erd.entityRelationship.Relationship
import java.util.Set
import org.eclipse.xtext.util.RuntimeIOException
import org.big.erd.entityRelationship.CardinalityType

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class EntityRelationshipGenerator extends AbstractGenerator {

	override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
		
		val diagram = resource.contents.get(0) as Model
		
		// Check whether the generate option is set
		if (diagram.generateOption === null || diagram.generateOption.generateOptionType.toString === 'off') {
			return;
		}
		

		val name = (diagram.name ?: 'output') + '.sql'
		try {
			fsa.generateFile(name, '''
				«FOR entity : diagram.entities.reject[it.isWeak]»
					«entity.toTable»
				«ENDFOR»
				«FOR relationship : diagram.relationships.reject[!it.isWeak]»
					«relationship.weakToTable»
				«ENDFOR»
				«FOR relationship : diagram.relationships.reject[it.isWeak]»
					«relationship.toTable»
				«ENDFOR»
				
			'''
			)
		} catch (RuntimeIOException e) {
			throw new Error("Could not generate file. Did you open a folder?")
		}
	}
	
	private def toTable(Entity entity) {
		return ''' 
			CREATE TABLE «entity.name»(
			«FOR attribute : entity.allAttributes.reject[it.type === AttributeType.DERIVED]»
				«'\t'»«attribute.name» «attribute.datatype.transformDataType»,
			«ENDFOR»
			«'\t'»PRIMARY KEY («entity.primaryKey.name»)
			);«'\n'»«'\n'»
		'''
	}
	
	private def toTable(Relationship relationship) {
		val keySource = relationship.first.target?.primaryKey
		val keyTarget = relationship.second.target?.primaryKey
		return ''' 
			CREATE TABLE «relationship.name»(
			«relationship.first.target.foreignKeyRef»
			«relationship.second.target.foreignKeyRef»
			«IF relationship.third?.target !== null», «relationship.third.target.foreignKeyRef»«ENDIF»
			«FOR attribute : relationship.attributes»
				«'\t'»«attribute.name» «attribute.datatype.transformDataType»,
			«ENDFOR»
			«'\t'»PRIMARY KEY («keySource.name», «keyTarget.name»«IF relationship.third?.target !== null», «relationship.third.target.primaryKey.name»«ENDIF»)
			);«'\n'»«'\n'»
		'''
	}
	
	private def weakToTable(Relationship relationship) {
		val strong = getStrongEntity(relationship)
		val weak = getWeakEntity(relationship)
		return ''' 
			CREATE TABLE «weak.name»(
			«FOR attribute : weak.allAttributes.reject[it.type === AttributeType.DERIVED]»
				«'\t'»«attribute.name» «attribute.datatype.transformDataType»,
			«ENDFOR»
			«FOR attribute : relationship.attributes»
				«'\t'»«attribute.name» «attribute.datatype.transformDataType»,
			«ENDFOR»
			«'\t'»«strong.primaryKey.name» «strong.primaryKey.datatype.transformDataType»,
			«'\t'»PRIMARY KEY («weak.partialKey.name», «strong.primaryKey.name»),
			«'\t'»FOREIGN KEY («strong.primaryKey.name») references «strong.name» ON DELETE CASCASE
			);«'\n'»«'\n'»
		'''
	}
	
	
	private def foreignKeyRef(Entity entity) {
		val key = entity.attributes.filter[a | a.type === AttributeType.KEY]
		if (key.nullOrEmpty) {
			val attr = entity.attributes.get(0)
			return '''«'\t'»«attr.name» «attr.datatype.transformDataType» references «entity.name»(«attr.name»),'''
		}
		return '''
			«'\t'»«key.get(0).name» «key.get(0).datatype.transformDataType» references «entity.name»(«key.get(0).name»),
		'''
	}

	private def primaryKey(Entity entity) {
		val keyAttributes = entity.attributes?.filter[it.type === AttributeType.KEY]
		if (keyAttributes.nullOrEmpty)
			return entity.attributes.get(0)
		return keyAttributes.get(0)
	}
	
	private def partialKey(Entity entity) {
		val keyAttributes = entity.attributes?.filter[a | a.type === AttributeType.PARTIAL_KEY]
		if (keyAttributes.nullOrEmpty)
			return entity.attributes.get(0)
		return keyAttributes.get(0)
	}
	
	private def transformDataType(DataType dataType) {
		// default
		if(dataType === null) {
			return 'CHAR(20)'
		}
			
		val type = dataType.type
		var size = dataType.size
		
		if (size != 0) {
			return type +  '(' + size + ')';
		}
		
		return type
	}

	private def getStrongEntity(Relationship r) {
		if (r.first.target.isWeak) {
			return r.second.target
		} else {
			return r.first.target
		}
	}

	private def getWeakEntity(Relationship r) {
		if (r.first.target.isWeak) {
			return r.first.target
		} else {
			return r.second.target
		}
	}

	private def Set<Attribute> getAllAttributes(Entity entity) {
		val attributes = newHashSet
		attributes += entity.attributes
		return attributes
	}
	
	
}