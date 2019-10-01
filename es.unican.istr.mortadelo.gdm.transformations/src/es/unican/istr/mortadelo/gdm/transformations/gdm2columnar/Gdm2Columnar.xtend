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
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Entity
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Equality
import es.unican.istr.mortadelo.gdm.lang.gdmLang.GdmLangPackage
import es.unican.istr.mortadelo.gdm.lang.gdmLang.LessThan
import es.unican.istr.mortadelo.gdm.lang.gdmLang.LessThanOrEqual
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Model
import es.unican.istr.mortadelo.gdm.lang.gdmLang.MoreThan
import es.unican.istr.mortadelo.gdm.lang.gdmLang.MoreThanOrEqual
import es.unican.istr.mortadelo.gdm.lang.gdmLang.OrConjunction
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Query
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Reference
import es.unican.istr.mortadelo.gdm.transformations.common.Tree
import java.io.File
import java.io.IOException
import java.util.ArrayList
import java.util.Collections
import java.util.HashMap
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
    // tables generation
    for (query : gdm.queries) {
      val table = generateTable(query, cfFactory)
      cfModel.tables.add(table)
    }
    return cfModel
  }

  def private static generateTable(Query query,
      ColumnFamilyDataModelFactory cfFactory) {
    // ensureRowUniqueness(table, query)
    val partitionAttributes = getEqualities(query.condition)
        .map[eq | eq.selection.attribute]
    val orderingAttributes = new ArrayList<Attribute>
    orderingAttributes.addAll(
      getInequalities(query.condition).map[ineq | ineq.selection.attribute])
    // query ordering is only added if compatible with the ordering obtained
    //   from the inequalities, i.e.,
    // inequalities ordering contained in query ordering (and same attr order)
    val queryOrderingAttributes = query.orderingAttributes
        .map[ordattr | ordattr.attribute]
    if (compatibleOrdering(orderingAttributes, queryOrderingAttributes)) {
      for (attr : queryOrderingAttributes) {
        if (!orderingAttributes.contains(attr)) {
          orderingAttributes.add(attr)
        }
      }
    }
    // include extra attributes to ensure row uniqueness
    ensureRowUniqueness(query, partitionAttributes, orderingAttributes)
    // create the final table
    val Map<Attribute, Column> attr2column = new HashMap<Attribute, Column>
    val table = cfFactory.createTable()
    table.name = query.name
    for (projection : query.projections) {
      val column = cfFactory.createColumn
      column.name = getName(projection)
      column.type = getType(cfFactory, projection.attribute)
      table.columns.add(column)
      attr2column.put(projection.attribute, column)
    }
    val projectionAttributes = query.projections.map[p | p.attribute]
    for (partitionAttribute : partitionAttributes) {
      var Column column = null
      if (projectionAttributes.contains(partitionAttribute)) {
        column = attr2column.get(partitionAttribute)
      } else {
        // create new column that was not present in the projection
        column = cfFactory.createColumn
        column.name = partitionAttribute.name
        column.type = getType(cfFactory, partitionAttribute)
        table.columns.add(column)
      }
      val partitionKey = cfFactory.createPartitionKey
      partitionKey.column = column
      table.partitionKeys.add(partitionKey)
    }
    for (orderingAttribute : orderingAttributes) {
      var Column column = null
      if (projectionAttributes.contains(orderingAttribute)) {
        column = attr2column.get(orderingAttribute)
      } else {
        // create new column that was not present in the projection
        column = cfFactory.createColumn
        column.name = orderingAttribute.name
        column.type = getType(cfFactory, orderingAttribute)
        table.columns.add(column)
      }
      val clusteringKey = cfFactory.createClusteringKey
      clusteringKey.column = column
      table.clusteringKeys.add(clusteringKey)
    }
    return table
  }

  /**
   * Add any extra required attributes to guarantee row uniqueness of the
   * resulting table
   */
  def private static void ensureRowUniqueness(Query query,
      List<Attribute> partitionAttributes, List<Attribute> orderingAttributes) {
    // ensure uniqueness for main entity
    val mainEntity = query.from.entity
    val List<Attribute> uniqueAttrs = mainEntity.getUniqueAttributes()
    if (uniqueAttrs.isEmpty()) {
      System.err.println(String.format(
          "The selected main entity for query %s has no unique attributes",
          query.name))
      System.exit(1)
    }
    if (!partitionAttributes.containsOne(uniqueAttrs) &&
        !orderingAttributes.containsOne(uniqueAttrs)) {
      // add one (the first, for example) to the clustering key
      orderingAttributes.add(uniqueAttrs.get(0))
    }
    // ensure uniqueness for reference paths
    val Tree<Reference> tree = createAccessTree(query)
    for (child : tree.children) {
      ensureSubpathUniqueness(child, child.data.entity,
            partitionAttributes, orderingAttributes)
    }
  }

  def private static void ensureSubpathUniqueness(
      Tree<Reference> tree, Entity entity,
      List<Attribute> partitionAttributes, List<Attribute> orderingAttributes) {
    if (!tree.data.cardinality.equals("1")) {
      // the subpath needs a unique identifier, starting with this entity
      //   this identifier can be obtained from the current entity, or from
      //   any entity connected with 1-bounded references
      val uniqueAttrs = entity.getAllUniqueAttributes(tree)
      // also, the identifier may already be present
      if (!partitionAttributes.containsOne(uniqueAttrs) &&
          !orderingAttributes.containsOne(uniqueAttrs)) {
        // add one (the first, for example) to the clustering key
        orderingAttributes.add(uniqueAttrs.get(0))
      }
    }
    // once this part of the path is identified, we continue
    for (child : tree.children) {
      ensureSubpathUniqueness(child, child.data.entity,
        partitionAttributes, orderingAttributes)
    }
  }

  /**
   * Get all unique attributes declared in a given entity
   */
  def private static List<Attribute> getUniqueAttributes(Entity entity) {
    return entity.features
                 .filter(f | f instanceof Attribute)
                 .map(f | (f as Attribute))
                 .filter[attr | attr.isUnique()]
                 .toList()
  }

  /**
   * Get all unique attributes of the entity and of those entities that are
   * reachable by traversing one or more 1-bounded references of the given
   * access tree
   */
  def private static List<Attribute> getAllUniqueAttributes(Entity entity,
      Tree<Reference> tree) {
    val uniqueAttrs = entity.getUniqueAttributes()
    for (child : tree.children) {
      if (child.data.cardinality.equals("1")) {
        uniqueAttrs.addAll(child.data.entity.getAllUniqueAttributes(child))
      }
    }
    return uniqueAttrs
  }

  /**
   * Check if attrs contains at least one attribute present in otherAttrs
   */
  def private static boolean containsOne(List<Attribute> attrs,
      List<Attribute> otherAttrs) {
    for (otherAttr : otherAttrs) {
      if (attrs.contains(otherAttr)) {
        return true
      }
    }
    return false
  }

  def private static Tree<Reference> createAccessTree(Query query) {
    // root element of the tree has no reference
    val tree = new Tree<Reference> (null)
    for (inclusion : query.inclusions) {
      // populate the tree with all the concatenated references
      var auxTree = tree
      for (ref : inclusion.refs) {
        val child = auxTree.add(ref)
        auxTree = child // we keep adding children down the rabbit hole
      }
    }
    return tree
  }

  def private static compatibleOrdering(
      List<Attribute> inequalitiesOrdering,
      List<Attribute> queryOrdering) {
    val inequalityOrderingIterator = inequalitiesOrdering.iterator()
    val queryOrderingIterator = queryOrdering.iterator()

    while (inequalityOrderingIterator.hasNext() &&
        queryOrderingIterator.hasNext()) {
      val inequalityOrderingAttr = inequalityOrderingIterator.next()
      val queryOrderingAttr = queryOrderingIterator.next()
      if (!inequalityOrderingAttr.equals(queryOrderingAttr)){
        return false // incompatible ordering detected at this point
      }
    }
    // two possibilities: (1) the inequality ordering iterator is empty, and thus
    //   orderings are compatible; (2) not empty, not compatible
    if (!inequalityOrderingIterator.hasNext()) {
      return true
    } else {
      return false
    }
  }


  def private static List<Comparison> getInequalities(BooleanExpression expression) {
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

  def private static List<Equality> getEqualities(BooleanExpression expression) {
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
      Attribute attribute) {
    val SimpleType st = cfFactory.createSimpleType
    switch (attribute.type) {
      case ID: {
        st.type = PrimitiveType.ID
      }
      case BOOLEAN: {
        st.type = PrimitiveType.BOOLEAN
      }
      case NUMBER: {
        st.type = PrimitiveType.FLOAT
      }
      case DATE: {
        st.type = PrimitiveType.DATE
      }
      default: {
        st.type = PrimitiveType.TEXT
      }
    }
    return st
  }

  def private static getName(AttributeSelection selection) {
    if (selection.alias !== null) {
      return selection.alias
    }
    return selection.attribute.name
  }

}
