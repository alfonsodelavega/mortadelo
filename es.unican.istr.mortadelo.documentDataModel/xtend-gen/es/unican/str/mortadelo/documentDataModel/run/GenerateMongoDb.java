package es.unican.str.mortadelo.documentDataModel.run;

import org.eclipse.emf.common.util.URI;
import org.eclipse.epsilon.common.util.StringProperties;
import org.eclipse.epsilon.emc.emf.EmfModel;
import org.eclipse.epsilon.eol.models.IRelativePathResolver;
import org.eclipse.xtext.xbase.lib.Exceptions;
import org.eclipse.xtext.xbase.lib.InputOutput;

@SuppressWarnings("all")
public class GenerateMongoDb {
  public static void main(final String[] args) {
    try {
      final EmfModel documentDataModel = new EmfModel();
      final StringProperties properties = new StringProperties();
      properties.put(EmfModel.PROPERTY_NAME, "documentDataModel");
      properties.put(EmfModel.PROPERTY_FILE_BASED_METAMODEL_URI, 
        URI.createURI("model/documentDataModel.ecore".toString()));
      properties.put(EmfModel.PROPERTY_MODEL_URI, 
        URI.createURI("resources/onlineShopDDM.model").toString());
      properties.put(EmfModel.PROPERTY_READONLOAD, Boolean.valueOf(true));
      properties.put(EmfModel.PROPERTY_STOREONDISPOSAL, Boolean.valueOf(false));
      documentDataModel.load(properties, ((IRelativePathResolver) null));
      InputOutput.<String>println("Generation finished");
    } catch (Throwable _e) {
      throw Exceptions.sneakyThrow(_e);
    }
  }
}
