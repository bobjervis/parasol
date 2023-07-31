/*
   Copyright 2015 Robert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
/*
 *	Parasol root scope symbols.
 *
 *	These symbols are defined for all compilations.  No special
 *	declarations are needed to have these names defined.
 *	
 *	This is accomplished by import'ing the symbols that are defined for all 
 *	files and letting the normal scope rules do the rest. This file's UnitScope
 *	gets inserted as the root scope, the enclosing scope of all other file UnitScope's. 
 */
import parasol:types.short;
import parasol:types.int;
import parasol:types.long;
import parasol:types.byte;
import parasol:types.char;
import parasol:types.unsigned;
import parasol:types.float;
import parasol:types.double;
import parasol:text.string;
import parasol:text.substring;
import parasol:text.string16;
import parasol:text.substring16;
import parasol:types.var;
import parasol:types.address;
import parasol:types.boolean;
import parasol:types.ref;
import parasol:types.pointer;
import parasol:types.vector;
import parasol:types.map;
import parasol:exception.Exception;
import parasol:stream.Reader;
import parasol:stream.Writer;
import parasol:thread.Monitor;

import parasol:exception.assert;
import parasol:process.printf;

import parasol:types.undefined;

public class Array = var[];
public class Object = var[string];


