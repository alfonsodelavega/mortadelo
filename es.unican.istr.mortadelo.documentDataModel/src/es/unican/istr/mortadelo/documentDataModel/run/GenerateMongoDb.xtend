package es.unican.istr.mortadelo.documentDataModel.run

import java.io.File
import java.io.PrintWriter
import org.eclipse.emf.common.util.URI
import org.eclipse.epsilon.common.parse.problem.ParseProblem
import org.eclipse.epsilon.common.util.StringProperties
import org.eclipse.epsilon.egl.EglTemplateFactory
import org.eclipse.epsilon.egl.EglTemplateFactoryModuleAdapter
import org.eclipse.epsilon.emc.emf.EmfModel
import org.eclipse.epsilon.eol.models.IRelativePathResolver

class GenerateMongoDb {
  // Perform the code generation step
  def static void main(String[] args) {
    // Load the document data model
    val documentDataModel = new EmfModel()
    val properties = new StringProperties()
    properties.put(EmfModel.PROPERTY_NAME, "documentDataModel")
    properties.put(EmfModel.PROPERTY_FILE_BASED_METAMODEL_URI,
        URI.createURI(("model/documentDataModel.ecore").toString()))
    properties.put(EmfModel.PROPERTY_MODEL_URI,
        URI.createURI("resources/onlineShopDDM.model").toString())
    properties.put(EmfModel.PROPERTY_READONLOAD, true)
    properties.put(EmfModel.PROPERTY_STOREONDISPOSAL, false)
    documentDataModel.load(properties, null as IRelativePathResolver)
    // Prepare and execute the template
    val templateModule =
        new EglTemplateFactoryModuleAdapter(new EglTemplateFactory())
    templateModule.parse(
        new File("epsilon/mongodb/documentDataModel2mongodb.egl"))
    if (templateModule.getParseProblems().size() > 0) {
      System.err.println("Parse errors occured...");
      for (ParseProblem problem : templateModule.getParseProblems()) {
        System.err.println(problem.toString());
      }
      return;
    }
    templateModule.getContext().getModelRepository().addModel(documentDataModel)
    val result = templateModule.execute
    templateModule.getContext().getModelRepository().dispose()
    // Print the results to a file
    val out = new PrintWriter("codeGen/onlineShopMongodb.js")
    out.println(result)
    out.close
    println("Generation finished")
  }
}