# Mortadelo

Copyright (C)  2018 Software Engineering and Real-Time, University of Cantabria

Mortadelo is a tool that allows to generate NoSQL schemas from a conceptual specification of a database.

The generic specification is defined through an instance of a *Generic Data Model* (GDM) metamodel.

This repository contains all metamodels of Mortadelo's translation process, and the transformations and code generation templates that are used to transform a GDM instance into final implementation schemas in Cassandra and/or MongoDB.

This tool is in a very early stage of development, so expect bugs and considerable (and probably breaking) changes of its contents.

## Structure of the *es.unican.istr.mortadelo.\[...\]* projects

- ***columnFamilyDataModel*** : Includes a metamodel for the logical description of column family-based data stores, and code generation templates to obtain Cassandra schemas.
- ***documentDataModel*** : Metamodel for the logical description of document-based data stores, and code generation templates for MongoDB schemas.
- ***gdm.lang.parent*** : Xtext language for the textual definition of GDM instances.
- ***gdm.examples*** : Includes a project example with an instantiation of the GDM through the defined Xtext language.
- ***gdm.transformations*** : Contains Xtend model-to-model transformations for the translation of GDM instances into column family or document models.

## Required Eclipse Packages

- Xtext.
- Epsilon
- (Optional) Plantuml for Ecore packages for easy visualization.

## Installation and Usage

1. Import all projects but the examples project into Eclipse.
2. Generate model code for columnFamilyDataModel and documentDataModel projects. Double click in model/(...).genmodel file and then right click ->generate model code.
3. Generate Xtext artifacts from .xtext grammar of gdm.lang/src.

You can run the Xtext editor with the LaunchRuntimeGdmLang.launch run configuration on gdm.lang.parent project. On the newly opened Eclipse instance, import the gdm.examples project to see a .gdm example of an online shop.

## License

GNU General Public License version 2 or (at your option) any later version.

See LICENSE and LICENSE.gpl-2.0+ for details.
