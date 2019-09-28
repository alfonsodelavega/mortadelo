package es.unican.istr.mortadelo.gdm.transformations.gdm2document

import columnFamilyDataModel.ColumnFamilyDataModelPackage
import documentDataModel.DocumentDataModel
import documentDataModel.DocumentDataModelFactory
import es.unican.istr.mortadelo.gdm.lang.gdmLang.GdmLangPackage
import es.unican.istr.mortadelo.gdm.lang.gdmLang.Model
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
    return docModel
  }
}