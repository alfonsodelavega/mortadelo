package es.unican.istr.mortadelo.gdm.transformations.gdm2columnar

import columnFamilyDataModel.Column
import columnFamilyDataModel.ColumnFamilyDataModel
import columnFamilyDataModel.ColumnFamilyDataModelFactory
import columnFamilyDataModel.ColumnFamilyDataModelPackage
import columnFamilyDataModel.PrimitiveType
import columnFamilyDataModel.SimpleType
import es.unican.istr.mortadelo.gdm.lang.gdmLang.AndConjunction
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Attribute
import es.unican.istr.mortadelo.gdm.lang.gdmLang.AttributeSelection
import es.unican.istr.mortadelo.gdm.lang.gdmLang.BooleanExpression
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Comparison
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Equality
import es.unican.istr.mortadelo.gdm.lang.gdmLang.GdmLangPackage
import es.unican.istr.mortadelo.gdm.lang.gdmLang.LessThan
import es.unican.istr.mortadelo.gdm.lang.gdmLang.LessThanOrEqual
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Model
import es.unican.istr.mortadelo.gdm.lang.gdmLang.MoreThan
import es.unican.istr.mortadelo.gdm.lang.gdmLang.MoreThanOrEqual
import es.unican.istr.mortadelo.gdm.lang.gdmLang.OrConjunction
import java.io.File
import java.io.IOException
import java.util.ArrayList
import java.util.Collections
import java.util.HashMap
import java.util.LinkedHashSet
import java.util.List
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl

class Gdm2Columnar {

  // Test the transformation below
  def static void main(String[] args) {
    val example = "eCommerce"
    // Prepare the xmi resource persistence
    val Resource.Factory.Registry reg = Resource.Factory.Registry.INSTANCE
    val m = reg.extensionToFactoryMap
    m.put("model", new XMIResourceFactoryImpl())
    // Initialize models
    GdmLangPackage.eINSTANCE.eClass
    ColumnFamilyDataModelPackage.eINSTANCE.eClass
    // Load the GDM model
    val input = new File(
      String.format("../es.unican.istr.mortadelo.gdm.examples/%s.model",
                    example))
    val resSet = new ResourceSetImpl()
    val inputResource = resSet.getResource(URI.createURI(input.canonicalPath),
      true
    )
    val gdm = inputResource.contents.get(0) as Model
    // Transform it
    val columnFamilyDM = transformGdm2Columnar(gdm)
    // Save the columnar data model
    val output = new File(
      String.format("../es.unican.istr.mortadelo.gdm.examples/columnFamily/%sCF.model",
                    example))
    val outputResource = resSet.createResource(
      URI.createURI(output.canonicalPath)
    )
    outputResource.getContents().add(columnFamilyDM)
    try {
      outputResource.save(Collections.EMPTY_MAP)
    } catch (IOException e) {
      e.printStackTrace()
    }
    println("Transformation finished")
  }

  def static ColumnFamilyDataModel transformGdm2Columnar(Model gdm) {
    val cfFactory = ColumnFamilyDataModelFactory.eINSTANCE
    val ColumnFamilyDataModel cfModel = cfFactory.createColumnFamilyDataModel()
    for (query : gdm.queries) {
      val columnFamily = cfFactory.createColumnFamily
      columnFamily.name = query.name
      cfModel.columnFamilies.add(columnFamily)
      val Map<Attribute, Column> attr2column = new HashMap<Attribute, Column>
      for (projection : query.projections) {
        val column = cfFactory.createColumn
        column.name = getName(projection)
        column.type = getType(cfFactory, projection)
        columnFamily.columns.add(column)
        attr2column.put(projection.attribute, column)
      }
      val equalities = getEqualities(query.condition)
      for (equality : equalities) {
        val partitionKey = cfFactory.createPartitionKey
        partitionKey.column = attr2column.get(equality.selection.attribute)
        columnFamily.partitionKeys.add(partitionKey)
      }
      val orderingAttributesSet = new LinkedHashSet<Attribute>
      orderingAttributesSet.addAll(
        getInequalities(query.condition).map[ineq | ineq.selection.attribute])
      orderingAttributesSet.addAll(
        query.orderingAttributes.map[ordattr | ordattr.attribute])
      for (orderingAttribute : orderingAttributesSet) {
        val clusteringKey = cfFactory.createClusteringKey
        clusteringKey.column = attr2column.get(orderingAttribute)
        columnFamily.clusteringKeys.add(clusteringKey)
      }
    }
    return cfModel
  }

  def static List<Comparison> getInequalities(BooleanExpression expression) {
    val inequalities = new ArrayList<Comparison>
    if (expression instanceof AndConjunction) {
      inequalities.addAll(getInequalities((expression as AndConjunction).left))
      inequalities.addAll(getInequalities((expression as AndConjunction).right))
    } else if (expression instanceof OrConjunction) {
      inequalities.addAll(getInequalities((expression as OrConjunction).left))
      inequalities.addAll(getInequalities((expression as OrConjunction).right))
    } else if (expression instanceof MoreThan ||
               expression instanceof MoreThanOrEqual ||
               expression instanceof LessThan ||
               expression instanceof LessThanOrEqual) {
      inequalities.add(expression as Comparison)
    }
    return inequalities
  }

  def static List<Equality> getEqualities(BooleanExpression expression) {
    val equalities = new ArrayList<Equality>
    if (expression instanceof AndConjunction) {
      equalities.addAll(getEqualities((expression as AndConjunction).left))
      equalities.addAll(getEqualities((expression as AndConjunction).right))
    } else if (expression instanceof OrConjunction) {
      equalities.addAll(getEqualities((expression as OrConjunction).left))
      equalities.addAll(getEqualities((expression as OrConjunction).right))
    } else if (expression instanceof Equality) {
      equalities.add(expression as Equality)
    }
    return equalities
  }

  def private static getType(ColumnFamilyDataModelFactory cfFactory,
      AttributeSelection selection) {
    switch (selection.attribute.type) {
      case ID: {
        val SimpleType st = cfFactory.createSimpleType
        st.type = PrimitiveType.ID
        return st
      }
      case TEXT: {
        val SimpleType st = cfFactory.createSimpleType
        st.type = PrimitiveType.TEXT
        return st
      }
      case BOOLEAN: {
        val SimpleType st = cfFactory.createSimpleType
        st.type = PrimitiveType.BOOLEAN
        return st
      }
      case NUMBER: {
        val SimpleType st = cfFactory.createSimpleType
        st.type = PrimitiveType.FLOAT
        return st
      }
      case DATE: {
        val SimpleType st = cfFactory.createSimpleType
        st.type = PrimitiveType.DATE
        return st
      }
    }
  }

  def private static getName(AttributeSelection selection) {
    if (selection.alias !== null) {
      return selection.alias
    }
    return selection.attribute.name
  }

}
