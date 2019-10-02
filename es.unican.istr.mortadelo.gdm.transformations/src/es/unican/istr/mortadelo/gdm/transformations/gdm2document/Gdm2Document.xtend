package es.unican.istr.mortadelo.gdm.transformations.gdm2document

import columnFamilyDataModel.ColumnFamilyDataModelPackage
import documentDataModel.Document
import documentDataModel.DocumentDataModel
import documentDataModel.DocumentDataModelFactory
import documentDataModel.Field
import documentDataModel.PrimitiveField
import documentDataModel.PrimitiveType
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Attribute
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Entity
import es.unican.istr.mortadelo.gdm.lang.gdmLang.GdmLangPackage
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Model
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Query
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Reference
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Type
import es.unican.istr.mortadelo.gdm.transformations.common.Tree
import java.io.File
import java.io.IOException
import java.util.ArrayList
import java.util.Collection
import java.util.Collections
import java.util.List
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl

class Gdm2Document {

  // Test the transformation below
  def static void main(String[] args) {
    val example = "eCommerce"
    println("GDM to document logical model")
    println(String.format("Example: %s", example))
    val totalStart = System.currentTimeMillis()
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
                                           true)
    val gdm = inputResource.contents.get(0) as Model
    // Transform it
    val start = System.currentTimeMillis()
    val columnFamilyDM = transformGdm2Document(gdm)
    val end = System.currentTimeMillis()
    // Save the obtained data model
    val output = new File(
      String.format("../es.unican.istr.mortadelo.gdm.examples/document/%sDOC.model",
                    example))
    val outputResource = resSet.createResource(
      URI.createURI(output.canonicalPath))
    outputResource.getContents().add(columnFamilyDM)
    try {
      outputResource.save(Collections.EMPTY_MAP)
    } catch (IOException e) {
      e.printStackTrace()
    }
    val totalEnd = System.currentTimeMillis()
    println("Transformation finished")
    println(String.format("Transformation time: %d ms", end - start))
    println(String.format("Total time (read/write files and models): %d ms",
        totalEnd - totalStart))
  }

  def static DocumentDataModel transformGdm2Document(Model gdm) {
    val docFactory = DocumentDataModelFactory.eINSTANCE
    val DocumentDataModel docModel = docFactory.createDocumentDataModel()
    // obtain main entities (those appearing in a from clause) and their queries
    val mainEntities = gdm.queries.map[q | q.from.entity].toSet
    val entityToQueries =  mainEntities.map[me |
      me -> gdm.queries.filter[q | q.from.entity.equals(me)]]
    // generate access trees
    val entity2accessTree = newImmutableMap(
      entityToQueries.map[e2q |
                          e2q.key -> createAccessTree(e2q.value)])
    // complete each access tree with the information of the rest
    for (entity : mainEntities) {
      val tree = entity2accessTree.get(entity)
      val otherTrees = new ArrayList<Tree<Reference>> (entity2accessTree.values)
      otherTrees.remove(tree)
      completeAccessTree(entity, tree, otherTrees)
    }
    // collections generation
    for (entity : mainEntities) {
      val tree = entity2accessTree.get(entity)
      val newCol = docFactory.createCollection()
      newCol.name = entity.name
      val docType = docFactory.createDocument()
      docType.name = "root"
      newCol.root = docType
      populateDocument(docType, docFactory, entity, tree, mainEntities)
      docModel.collections.add(newCol)
    }
    return docModel
  }

  /**
   *  Obtains the access tree of an entity, including the reference traversed
   *  for each step of the path
   *
   *  @returns A tree of pairs (traversed reference, destination entity)
   */
  def private static Tree<Reference> createAccessTree(Iterable<Query> queries) {
    // root element of the tree has no reference
    val tree = new Tree<Reference> (null)
    for (query : queries) {
      for (inclusion : query.inclusions) {
        // populate the tree with all the concatenated references
        // the add method of the tree handles collisions for us
        var auxTree = tree
        for (ref : inclusion.refs) {
          val child = auxTree.add(ref)
          auxTree = child // we keep adding children down the rabbit hole
        }
      }
    }
    return tree
  }

  def private static void completeAccessTree(Entity entity, Tree<Reference> tree,
      Collection<Tree<Reference>> otherTrees) {
    for (oTree : otherTrees) {
      val treeNodes = searchEntity(entity, oTree)
      for (treeNode : treeNodes) {
        addTreeNode(tree, treeNode)
      }
    }
  }

  def private static List<Tree<Reference>> searchEntity(Entity entity,
      Tree<Reference> tree) {
    val treeNodes = new ArrayList<Tree<Reference>>()
    for (child : tree.children) {
      if (child.data.entity.equals(entity)) {
        treeNodes.add(child)
      }
      treeNodes.addAll(searchEntity(entity, child))
    }
    return treeNodes
  }

  def private static void addTreeNode(Tree<Reference> tree, Tree<Reference> treeNode) {
    for (child : treeNode.children) {
      val addedChild = tree.add(child.data)
      addTreeNode(addedChild, child)
    }
  }

  def private static void populateDocument(Document document,
      DocumentDataModelFactory docFactory, Entity entity, Tree<Reference> tree,
      Set<Entity> mainEntities) {
    addAttributes(document, entity, docFactory)
    for (child : tree.children) {
      val reference = child.data
      // main entity pruning: if reference points to a main entity, instead of
      //   generating the document we create a reference
      var Field newField = null
      if (mainEntities.contains(reference.entity)) {
        newField = docFactory.createPrimitiveField()
        newField.name = reference.entity.name.toFirstLower + "Ref"
        (newField as PrimitiveField).type = PrimitiveType.ID
      } else {
        newField = docFactory.createDocument()
        newField.name = reference.entity.name.toFirstLower
        populateDocument(newField as Document, docFactory, reference.entity,
          child, mainEntities)
      }
      if (!reference.cardinality.equals("1")) {
        // encapsulate field in an array
        val arrayField = docFactory.createArrayField()
        arrayField.name = newField.name + "Array"
        arrayField.type = newField
        document.fields.add(arrayField)
      } else {
        document.fields.add(newField)
      }
    }
  }

  def private static void addAttributes(Document document, Entity entity,
      DocumentDataModelFactory docFactory) {
    for (attr : entity.features.filter[f | f instanceof Attribute]) {
      val field = docFactory.createPrimitiveField()
      field.name = attr.name
      field.type = convertType((attr as Attribute).type)
      document.fields.add(field)
    }
  }

  def private static PrimitiveType convertType(Type type) {
    switch(type) {
      case ID:
        return PrimitiveType.ID
      case NUMBER:
        return PrimitiveType.FLOAT
      case DATE:
        return PrimitiveType.DATE
      case BOOLEAN:
        return PrimitiveType.BOOLEAN
      default:
        return PrimitiveType.TEXT
    }
  }
}
