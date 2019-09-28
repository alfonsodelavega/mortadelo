package es.unican.istr.mortadelo.gdm.transformations.gdm2document

import columnFamilyDataModel.ColumnFamilyDataModelPackage
import documentDataModel.DocumentDataModel
import documentDataModel.DocumentDataModelFactory
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Entity
import es.unican.istr.mortadelo.gdm.lang.gdmLang.GdmLangPackage
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Model
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Query
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Reference
import java.io.File
import java.io.IOException
import java.util.Collections
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl

class Gdm2Document {
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
                                           true)
    val gdm = inputResource.contents.get(0) as Model
    // Transform it
    val columnFamilyDM = transformGdm2Document(gdm)
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
    println("Transformation finished")
  }

  def static DocumentDataModel transformGdm2Document(Model gdm) {
    val docFactory = DocumentDataModelFactory.eINSTANCE
    val DocumentDataModel docModel = docFactory.createDocumentDataModel()
    // obtain main entities (those appearing in a from clause) and their queries
    val mainEntities = gdm.queries.map[q | q.from.entity].toSet
    val entityToQueries =  mainEntities.map[me |
      me -> gdm.queries.filter[q | q.from.entity.equals(me)]]
    // generate access trees
    val accessTrees = entityToQueries.map[e2q | createAccessTree(e2q.key, e2q.value)]
    for (tree : accessTrees) {
      println(tree)
      println()
    }
    // complete each access tree with the information of the rest
    // collections generation
    for (entity : mainEntities) {
      val newCol = docFactory.createCollection()
      newCol.name = entity.name
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
  def private static Tree<Pair<Reference, Entity>> createAccessTree(Entity mainEntity,
      Iterable<Query> queries) {
    // root element of the tree has no reference
    val tree = new Tree<Pair<Reference, Entity>> (null -> mainEntity);
    for (query : queries) {
      for (inclusion : query.inclusions) {
        // populate the tree with all the concatenated references
        // the add method of the tree handles collisions for us
        var auxTree = tree
        for (ref : inclusion.refs) {
          val child = auxTree.add(ref -> ref.entity)
          auxTree = child // we keep adding children down the rabbit hole
        }
      }
    }
    return tree
  }
}