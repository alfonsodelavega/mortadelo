/*
 * generated by Xtext 2.13.0
 */
package es.unican.istr.mortadelo.gdm.lang.web

import com.google.inject.Guice
import com.google.inject.Injector
import es.unican.istr.mortadelo.gdm.lang.GdmLangRuntimeModule
import es.unican.istr.mortadelo.gdm.lang.GdmLangStandaloneSetup
import es.unican.istr.mortadelo.gdm.lang.ide.GdmLangIdeModule
import org.eclipse.xtext.util.Modules2

/**
 * Initialization support for running Xtext languages in web applications.
 */
class GdmLangWebSetup extends GdmLangStandaloneSetup {
	
	override Injector createInjector() {
		return Guice.createInjector(Modules2.mixin(new GdmLangRuntimeModule, new GdmLangIdeModule, new GdmLangWebModule))
	}
	
}
