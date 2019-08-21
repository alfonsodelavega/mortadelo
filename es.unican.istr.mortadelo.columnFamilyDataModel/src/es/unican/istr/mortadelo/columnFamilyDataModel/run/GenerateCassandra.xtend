package es.unican.istr.mortadelo.columnFamilyDataModel.run

import java.io.File
import java.io.PrintWriter
import org.eclipse.emf.common.util.URI
import org.eclipse.epsilon.common.parse.problem.ParseProblem
import org.eclipse.epsilon.common.util.StringProperties
import org.eclipse.epsilon.egl.EglTemplateFactory
import org.eclipse.epsilon.egl.EglTemplateFactoryModuleAdapter
import org.eclipse.epsilon.emc.emf.EmfModel
import org.eclipse.epsilon.eol.models.IRelativePathResolver

class GenerateCassandra {
  // Perform the code generation step
  def static void main(String[] args) {
    // Load the document data model
    val documentDataModel = new EmfModel()
    val properties = new StringProperties()
    properties.put(EmfModel.PROPERTY_NAME, "columnFamilyDataModel")
    properties.put(EmfModel.PROPERTY_FILE_BASED_METAMODEL_URI,
        URI.createURI(("model/columnFamilyDataModel.ecore").toString()))
    properties.put(EmfModel.PROPERTY_MODEL_URI,
        URI.createURI("resources/eCommerceCF.model").toString())
    properties.put(EmfModel.PROPERTY_READONLOAD, true)
    properties.put(EmfModel.PROPERTY_STOREONDISPOSAL, false)
    documentDataModel.load(properties, null as IRelativePathResolver)
    // Prepare and execute the template
    val templateModule =
        new EglTemplateFactoryModuleAdapter(new EglTemplateFactory())
    templateModule.parse(
        new File("epsilon/cassandra/columnFamilyDataModel2cassandra.egl"))
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
    val out = new PrintWriter("codeGen/eCommerce.cql")
    out.println(result)
    out.close
    println("Generation finished")
  }
}