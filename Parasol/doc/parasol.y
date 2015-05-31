
	// Each of these tokens has an associated 'value'

%token IDENTIFIER
%token INTEGER
%token FLOATING_POINT
%token CHARACTER
%token STRING
%token ANNOTATION

	// Each of these tokens is a simple value.

%token SEMI_COLON
%token COLON
%token DOT
%token EXCLAMATION

	// Each of these are paired tokens:

%token LEFT_PARENTHESIS
%token RIGHT_PARENTHESIS
%token LEFT_CURLY
%token RIGHT_CURLY
%token LEFT_SQUARE
%token RIGHT_SQUARE
%token LP_LA
%token RA_RP

	// These are operator-like tokens appearing in expressions:

%left	ASTERISK SLASH PERCENT
%left	PLUS DASH
%left	LA_LA RA_RA RA_RA_RA
%left	DOT_DOT
%left	EQ_EQ EXCLAMATION_EQ EQ_EQ_EQ EX_EQ_EQ
%left	LEFT_ANGLE RIGHT_ANGLE RA_EQ LA_EQ LA_RA LA_RA_EQ EX_RA EX_LA EX_RA_EQ EX_LA_EQ EX_LA_RA EX_LA_RA_EQ
%left	AMPERSAND CARET VERTICAL_BAR
%left	AMP_AMP VBAR_VBAR
%left	NEW DELETE
%right	EQUALS PLUS_EQ DASH_EQ ASTERISK_EQ SLASH_EQ PERCENT_EQ AMPERSAND_EQ CARET_EQ VERTICAL_BAR_EQ LA_LA_EQ RA_RA_EQ RA_RA_RA_EQ
%left	COMMA

%token QUESTION_MARK
%token TILDE

	// These are multi-character operator-like tokens:

%token PLUS_PLUS					// ++
%token DASH_DASH					// --
%token ELLIPSIS						// ...

	// Keywords

%token ABSTRACT
%token BREAK
%token BYTES
%token CASE
%token CATCH
%token CLASS
%token CONTINUE
%token DEFAULT
%token DO
%token ELSE
%token ENUM
%token EXTENDS
%token FALSE
%token FINAL
%token FINALLY
%token FOR
%token FUNCTION
%token IF
%token IMPLEMENTS
%token IMPORT
%token NAMESPACE
%token NULL
%token PRIVATE
%token PROTECTED
%token PUBLIC
%token RETURN
%token STATIC
%token SUPER
%token SWITCH
%token THIS
%token THROW
%token TRUE
%token TRY
%token WHILE

%token CLASS_NAME				// designate the name for a constructor
%%
statement_list_opt:
			  /* empty */
			| statement_list
			;
			
statement_list:
			  annotation_list_opt statement
			| statement_list annotation_list_opt statement
			;
			
statement:	  SEMI_COLON
			| expression SEMI_COLON
			| expression catch_clause
			| block
			| visibility declaration
			| declaration
			| BREAK SEMI_COLON
			| CASE expression COLON statement
			| CONTINUE SEMI_COLON
			| DEFAULT COLON statement
			| DO statement WHILE LEFT_PARENTHESIS expression RIGHT_PARENTHESIS SEMI_COLON
			| FOR LEFT_PARENTHESIS expression_opt SEMI_COLON expression_opt SEMI_COLON expression_opt RIGHT_PARENTHESIS statement
			| FOR LEFT_PARENTHESIS expression IDENTIFIER COLON expression RIGHT_PARENTHESIS statement
			| FOR LEFT_PARENTHESIS expression IDENTIFIER EQUALS expression SEMI_COLON expression_opt SEMI_COLON expression_opt RIGHT_PARENTHESIS statement
			| IF LEFT_PARENTHESIS expression RIGHT_PARENTHESIS statement else_opt
			| RETURN expression_opt SEMI_COLON
			| SWITCH LEFT_PARENTHESIS expression RIGHT_PARENTHESIS statement
			| THROW expression SEMI_COLON
			| TRY block catch_clause
			| WHILE LEFT_PARENTHESIS expression RIGHT_PARENTHESIS statement
			| import
			| NAMESPACE namespace SEMI_COLON
			;

catch_clause: catch_list finally_opt
			;
			
finally_opt:  /* empty */
			| FINALLY block
			;
			
catch_list:	  catch
			| catch_list catch
			;

catch:		  CATCH LEFT_PARENTHESIS IDENTIFIER IDENTIFIER RIGHT_PARENTHESIS block
			;
			
import:		  IMPORT IDENTIFIER EQUALS namespace DOT IDENTIFIER SEMI_COLON
			| IMPORT namespace DOT IDENTIFIER SEMI_COLON
			;
			
namespace:	  dotted_name LEFT_PARENTHESIS dotted_name RIGHT_PARENTHESIS
			;
			
dotted_name:  IDENTIFIER
			| dotted_name DOT IDENTIFIER
			;
			
block:		  LEFT_CURLY statement_list_opt RIGHT_CURLY
			;
		
visibility:	  PUBLIC
			| PROTECTED
			| PRIVATE
			;
				
declaration:
			  expression initializer_list SEMI_COLON
			| STATIC expression initializer_list SEMI_COLON
			| CLASS_NAME LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS function_body
			| FINAL CLASS IDENTIFIER class_body
			| CLASS IDENTIFIER class_body
			| ENUM IDENTIFIER LEFT_CURLY enum_body RIGHT_CURLY
			| FINAL expression name LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS function_body
			| expression name LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS function_body
			| STATIC expression name LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS function_body
			| ABSTRACT expression name LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS SEMI_COLON
			| TILDE CLASS_NAME LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS function_body
			;
			
enum_body:	  enum_list
			| enum_list SEMI_COLON statement_list_opt
			;
			
enum_list:	  enum
			| enum_list COMMA enum
			;
			
enum:		  IDENTIFIER
			| IDENTIFIER LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS
			;
			
function_body:
			  block
			| SEMI_COLON
			;

initializer_list:
			  initializer
			| initializer_list COMMA initializer
			;
			 
initializer:  name
			| name EQUALS assignment
			;
			
else_opt:	  /* empty */
			| ELSE statement
			;

name:		  annotation_list_opt IDENTIFIER
			;
				
expression_opt:
			  /* empty */
			| expression
			;
			
expression:	  assignment
			| expression COMMA assignment
			;

assignment:	  conditional
			| assignment EQUALS assignment
			| assignment PLUS_EQ assignment
			| assignment DASH_EQ assignment
			| assignment ASTERISK_EQ assignment
			| assignment SLASH_EQ assignment
			| assignment PERCENT_EQ assignment
			| assignment AMPERSAND_EQ assignment
			| assignment CARET_EQ assignment
			| assignment VERTICAL_BAR_EQ assignment
			| assignment LA_LA_EQ assignment
			| assignment RA_RA_EQ assignment
			| assignment RA_RA_RA_EQ assignment
			;
			
conditional:  binary
			| binary QUESTION_MARK expression COLON conditional
			;
 
binary:		  unary
			| binary ASTERISK binary
			| binary SLASH binary
			| binary PERCENT binary
			| binary PLUS binary
			| binary DASH binary
			| binary LA_LA binary
			| binary RA_RA binary
			| binary RA_RA_RA binary
			| binary DOT_DOT binary
			| binary EQ_EQ binary
			| binary EXCLAMATION_EQ binary
			| binary EQ_EQ_EQ binary
			| binary EX_EQ_EQ binary
			| binary LEFT_ANGLE binary
			| binary RIGHT_ANGLE binary
			| binary RA_EQ binary
			| binary LA_EQ binary
			| binary LA_RA binary
			| binary LA_RA_EQ binary
			| binary EX_RA binary
			| binary EX_LA binary
			| binary EX_RA_EQ binary
			| binary EX_LA_EQ binary
			| binary EX_LA_RA binary
			| binary EX_LA_RA_EQ binary
			| binary AMPERSAND binary
			| binary CARET binary
			| binary VERTICAL_BAR binary
			| binary AMP_AMP binary
			| binary VBAR_VBAR binary
			| binary NEW binary
			| binary DELETE binary
			;

unary:		  term
			| PLUS unary
			| DASH unary
			| TILDE unary	
			| AMPERSAND unary
			| EXCLAMATION unary
			| PLUS_PLUS unary
			| DASH_DASH unary
			| NEW unary
			| DELETE unary
			;
		
term:		  atom
			| term PLUS_PLUS
			| term DASH_DASH
			| term LEFT_PARENTHESIS parameter_list_opt RIGHT_PARENTHESIS
			| term LEFT_SQUARE expression_opt RIGHT_SQUARE value_initializer_list_opt
			| term LEFT_SQUARE expression COLON expression_opt RIGHT_SQUARE
			| term ELLIPSIS
			| term LP_LA expression RA_RP
			| term DOT IDENTIFIER
			| term DOT BYTES
			;
	
atom:		  IDENTIFIER
			| INTEGER
			| CHARACTER
			| STRING
			| FLOATING_POINT
			| THIS
			| SUPER
			| TRUE
			| FALSE
			| NULL
			| LEFT_PARENTHESIS expression RIGHT_PARENTHESIS
			| CLASS class_body
			| FUNCTION term_opt block
			;

value_initializer_list_opt:
			  /* empty */
			| LEFT_CURLY RIGHT_CURLY
			| LEFT_CURLY value_initializer_list RIGHT_CURLY
			;
			
value_initializer_list:
			  value_initializer
			| value_initializer_list COMMA value_initializer
			;
			
value_initializer:
			  assignment
 			;

term_opt:	  /* empty */
			| term
			;
			
class_body:	  template_opt base_opt implements_list_opt block
			;
			
template_opt:
			  /* empty */
			| LP_LA template_list RA_RP
			;
			
template_list:
			  annotation_list_opt template_arg
			| template_list COMMA annotation_list_opt template_arg
			;
			
template_arg:
			  CLASS IDENTIFIER
			| expression IDENTIFIER
			;
			
parameter_list_opt:
			  /* empty */
			| parameter_list
			;
			
parameter_list:
			  annotation_list_opt parameter
			| parameter_list COMMA annotation_list_opt parameter
			;
			
parameter:	  assignment
			| conditional IDENTIFIER
			;

annotation_list_opt:
			  /* empty */
			| annotation_list
			;
			
annotation_list:
			  annotation
			| annotation_list annotation
			;
			
annotation:	  ANNOTATION
			| ANNOTATION LEFT_PARENTHESIS argument_list_opt RIGHT_PARENTHESIS
			;

base_opt:	  /* empty */
			| EXTENDS expression
			;
			
implements_list_opt:
			  /* empty */		  
			| implements_list
			;
			
implements_list:
			  implements
			| implements_list implements
			;
			
implements:	  IMPLEMENTS expression
			;
			
argument_list_opt:
			  /* empty */
			| argument_list
			;
			
argument_list:
			  assignment
			| argument_list COMMA assignment
			;
