%name PHP_Parser
%declare_class {class PHP_Parser}

%syntax_error {
/* ?><?php */
    echo "Syntax Error on line " . $this->lex->line . ": token '" . 
        $this->lex->value . "' while parsing rule:";
    foreach ($this->yystack as $entry) {
        echo $this->tokenName($entry->major) . ' ';
    }
    foreach ($this->yy_get_expected_tokens($yymajor) as $token) {
        $expect[] = self::$yyTokenName[$token];
    }
    throw new Exception('Unexpected ' . $this->tokenName($yymajor) . '(' . $TOKEN
        . '), expected one of: ' . implode(',', $expect));
}
%include_class {
    static public $transTable = array();

    function __construct()
    {
        if (!count(self::$transTable)) {
            $start = 240; // start nice and low to be sure
            while (token_name($start) == 'UNKNOWN') {
                $start++;
            }
            $hash = array_flip(self::$yyTokenName);
            $map =
                array(
                    ord(',') => self::COMMA,
                    ord('=') => self::EQUALS,
                    ord('?') => self::QUESTION,
                    ord(':') => self::COLON,
                    ord('|') => self::BAR,
                    ord('^') => self::CARAT,
                    ord('&') => self::AMPERSAND,
                    ord('<') => self::LESSTHAN,
                    ord('>') => self::GREATERTHAN,
                    ord('+') => self::PLUS,
                    ord('-') => self::MINUS,
                    ord('.') => self::DOT,
                    ord('*') => self::TIMES,
                    ord('/') => self::DIVIDE,
                    ord('%') => self::PERCENT,
                    ord('!') => self::EXCLAM,
                    ord('~') => self::TILDE,
                    ord('@') => self::AT,
                    ord('[') => self::LBRACKET,
                    ord('(') => self::LPAREN,
                    ord(')') => self::RPAREN,
                    ord(';') => self::SEMI,
                    ord('{') => self::LCURLY,
                    ord('}') => self::RCURLY,
                    ord('`') => self::BACKQUOTE,
                    ord('$') => self::DOLLAR,
                    ord(']') => self::RBRACKET,
                    ord('"') => self::DOUBLEQUOTE,
                    ord("'") => self::SINGLEQUOTE,
                );
            for ($i = $start; $i < self::YYERRORSYMBOL + $start; $i++) {
                $lt = token_name($i);
                $lt = ($lt == 'T_DOUBLE_COLON') ?  'T_PAAMAYIM_NEKUDOTAYIM' : $lt;
//                echo "$lt has hash? ".$hash[$lt]."\n";
                if (!isset($hash[$lt])) {
                    continue;
                }
                
                //echo "compare $lt with {$tokens[$i]}\n";
                $map[$i] = $hash[$lt];
            }
            //print_r($map);
            // set the map to false if nothing in there.
            self::$transTable = $map;
        }
    }

    public $data;
}

%left T_INCLUDE T_INCLUDE_ONCE T_EVAL T_REQUIRE T_REQUIRE_ONCE.
%left COMMA.
%left T_LOGICAL_OR.
%left T_LOGICAL_XOR.
%left T_LOGICAL_AND.
%right T_PRINT.
%left EQUALS T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_CONCAT_EQUAL T_MOD_EQUAL T_AND_EQUAL T_OR_EQUAL T_XOR_EQUAL T_SL_EQUAL T_SR_EQUAL.
%left QUESTION COLON.
%left T_BOOLEAN_OR.
%left T_BOOLEAN_AND.
%left BAR.
%left CARAT.
%left AMPERSAND.
%nonassoc T_IS_EQUAL T_IS_NOT_EQUAL T_IS_IDENTICAL T_IS_NOT_IDENTICAL.
%nonassoc LESSTHAN T_IS_SMALLER_OR_EQUAL GREATERTHAN T_IS_GREATER_OR_EQUAL.
%left T_SL T_SR.
%left PLUS MINUS DOT.
%left TIMES DIVIDE PERCENT.
%right EXCLAM.
%nonassoc T_INSTANCEOF.
%right TILDE T_INC T_DEC T_INT_CAST T_DOUBLE_CAST T_STRING_CAST T_ARRAY_CAST T_OBJECT_CAST T_BOOL_CAST T_UNSET_CAST AT.
%right LBRACKET.
%nonassoc T_NEW T_CLONE.
%left T_ELSEIF.
%left T_ELSE.
%left T_ENDIF.
%right T_STATIC T_ABSTRACT T_FINAL T_PRIVATE T_PROTECTED T_PUBLIC.

%extra_argument {$lex}

%parse_accept {
    var_dump($this->data);
}

start ::= top_statement_list(B). {$this->data = B->metadata;}

top_statement_list(A) ::= top_statement_list(B) top_statement(C). {
    A = B;
    A[] = C;
}
top_statement_list(A) ::= . {A = new PHP_ParseryyToken('');}

top_statement(A) ::= statement(B). {A = B;}
top_statement(A) ::= function_declaration_statement(B). {A = B;}
top_statement(A) ::= class_declaration_statement(B). {A = B;}
top_statement ::= T_HALT_COMPILER LPAREN RPAREN SEMI. { $this->lex->haltParsing(); }

statement(A) ::= unticked_statement(B). {A = B;}

unticked_statement(A) ::= LCURLY inner_statement_list(B) RCURLY. {A = B;}
unticked_statement(A) ::= T_IF LPAREN expr(E) RPAREN statement(I) elseif_list(EL) else_single(ELL). {
    A = new PHP_ParseryyToken('');
    A[] = E;
    A[] = I;
    A[] = EL;
    A[] = ELL;
}
unticked_statement(A) ::= T_IF LPAREN expr(E) RPAREN COLON inner_statement_list(I) new_elseif_list(EL) new_else_single(ELL) T_ENDIF SEMI. {
    A = new PHP_ParseryyToken('if (' . E->string . '):' . I->string . EL->string . ELL->string . 'endif;');
    A[] = E;
    A[] = I;
    A[] = EL;
    A[] = ELL;
}
unticked_statement(A) ::= T_WHILE LPAREN expr(B) RPAREN while_statement(C). {
    A = new PHP_ParseryyToken('');
    A[] = B;
    A[] = C;
}
unticked_statement(A) ::= T_DO statement(B) T_WHILE LPAREN expr(C) RPAREN SEMI. {
    A = new PHP_ParseryyToken('');
    A[] = B;
    A[] = C;
}
unticked_statement(A) ::= T_FOR 
			LPAREN
				for_expr(B)
			COLON 
				for_expr(C)
			SEMI
				for_expr(D)
			RPAREN
			for_statement(E). {
    A = new PHP_ParseryyToken('');
    A[] = B;
    A[] = C;
    A[] = D;
    A[] = E;
}
unticked_statement(A) ::= T_SWITCH LPAREN expr(B) RPAREN switch_case_list(C). {
    A = new PHP_ParseryyToken('');
    A[] = B;
    A[] = C;
}
unticked_statement ::= T_BREAK SEMI.
unticked_statement(A) ::= T_BREAK expr(B) SEMI. {
    A = new PHP_ParseryyToken('');
    A[] = B;
}
unticked_statement ::= T_CONTINUE SEMI.
unticked_statement(A) ::= T_CONTINUE expr(B) SEMI. {
    A = new PHP_ParseryyToken('', B);
}
unticked_statement ::= T_RETURN SEMI.
unticked_statement(A) ::= T_RETURN expr_without_variable(B) SEMI. {
    A = new PHP_ParseryyToken('return ' . B->string . ';', B);
}
unticked_statement(A) ::= T_RETURN variable(B) SEMI. {
    A = new PHP_ParseryyToken('return ' . B->string . ';', B);
}
unticked_statement(A) ::= T_GLOBAL global_var_list(B) SEMI. {A = B;}
unticked_statement(A) ::= T_STATIC static_var_list(B) SEMI. {A = B;}
unticked_statement(A) ::= T_ECHO echo_expr_list(B) SEMI. {
    A = new PHP_ParseryyToken('', B);
}
unticked_statement ::= T_INLINE_HTML.
unticked_statement(A) ::= expr(B) SEMI. {A = B;}
unticked_statement(A) ::= T_USE use_filename(B) SEMI. {
    A = new PHP_ParseryyToken('', array('uses' => B));
    // not that "uses" would actually work in real life
}
unticked_statement(A) ::= T_UNSET LPAREN unset_variables(B) LPAREN SEMI. {
    A = new PHP_ParseryyToken('', B);
}
unticked_statement(A) ::= T_FOREACH LPAREN variable(B) T_AS 
		foreach_variable foreach_optional_arg RPAREN
		foreach_statement(C). {
    A = new PHP_ParseryyToken('', B);
    A[] = C;
}
unticked_statement(A) ::= T_FOREACH LPAREN expr_without_variable(B) T_AS 
		w_variable foreach_optional_arg RPAREN
		foreach_statement(C). {
    A = new PHP_ParseryyToken('', B);
    A[] = C;
}
unticked_statement(A) ::= T_DECLARE LPAREN declare_list(B) RPAREN declare_statement(C). {
    A = new PHP_ParseryyToken('', B);
    A[] = C;
}
unticked_statement ::= SEMI.
unticked_statement(A) ::= T_TRY LCURLY inner_statement_list(B) RCURLY
		T_CATCH LPAREN
		fully_qualified_class_name(C)
		T_VARIABLE RPAREN
		LCURLY inner_statement_list(D) RCURLY
		additional_catches(E). {
    A = new PHP_ParseryyToken('',
        array(
            'catches' => C,
        ));
    A[] = B;
    A[] = D;
    A[] = E;
}
unticked_statement(A) ::= T_THROW expr(B) SEMI. {
    if (B->metadata && isset(B->metadata[0]) && isset(B->metadata[0]['uses']) &&
          B->metadata[0]['uses'] === 'class') {
        A = new PHP_ParseryyToken('throw ' . B->string, array('throws' => B->metadata[0]['name']));
    } else {
        A = new PHP_ParseryyToken('throw ' . B->string);
        A[] = B;
    }
}

additional_catches(A) ::= non_empty_additional_catches(B). {A = B;}
additional_catches ::= .

non_empty_additional_catches(A) ::= additional_catch(B). {A = B;}
non_empty_additional_catches(A) ::= non_empty_additional_catches(B) additional_catch(C). {
    A = B;
    A[] = C;
}

additional_catch(A) ::= T_CATCH LPAREN fully_qualified_class_name(B) T_VARIABLE RPAREN LCURLY inner_statement_list(C) RCURLY. {
    A = new PHP_ParseryyToken('', C);
    A[] = array('catches' => B);
}

inner_statement_list(A) ::= inner_statement_list(B) inner_statement(C). {
    A = B;
    A[] = C;
}
inner_statement_list(A) ::= . {A = new PHP_ParseryyToken('');}

inner_statement(A) ::= statement(B). {
    A = new PHP_ParseryyToken(B);
}
inner_statement(A) ::= function_declaration_statement(B). {
    A = new PHP_ParseryyToken(B);
}
inner_statement(A) ::= class_declaration_statement(B). {
    A = new PHP_ParseryyToken(B);
}
inner_statement ::= T_HALT_COMPILER LPAREN RPAREN SEMI. { $this->lex->haltParsing(); }

function_declaration_statement(A) ::= unticked_function_declaration_statement(B). {
    A = new PHP_ParseryyToken(B);
}

class_declaration_statement(A) ::= unticked_class_declaration_statement(B). {
    A = new PHP_ParseryyToken(B);
}

unticked_function_declaration_statement(A) ::=
		T_FUNCTION is_reference(ref) T_STRING(funcname) LPAREN parameter_list(params) RPAREN
		LCURLY inner_statement_list(funcinfo) RCURLY. {
	A = new PHP_ParseryyToken('function ' . (ref ? '&' : '') .
	   funcname . '(' . params->string . ')');
    A[] = array(
        'type' => 'function',
        'returnsref' => ref,
        'name' => funcname,
        'parameters' => params->metadata,
        'info' => funcinfo->metadata,
    );
}

unticked_class_declaration_statement(A) ::=
		class_entry_type(classtype) T_STRING(C) extends_from(ext)
			implements_list(impl)
			LCURLY
				class_statement_list(cinfo)
			RCURLY. {
	A = new PHP_ParseryyToken('', array(
	   'type' => classtype['type'],
	   'modifiers' => classtype['modifiers'],
	   'name' => C,
	   'extends' => ext,
	   'implements' => impl,
	   'info' => cinfo->metadata,
	));
}
unticked_class_declaration_statement ::=
		interface_entry T_STRING
			interface_extends_list
			LCURLY
				class_statement_list
			RCURLY.

class_entry_type(A) ::= T_CLASS. { A = new PHP_ParseryyToken('', array('type' => 'class', 'modifiers' => array())); }
class_entry_type(A) ::= T_ABSTRACT T_CLASS. {
    A = new PHP_ParseryyToken('', array('type' => 'class', 'modifiers' => array('abstract')));
}
class_entry_type(A) ::= T_FINAL T_CLASS. {
    A = new PHP_ParseryyToken('', array('type' => 'class', 'modifiers' => array('final')));
}

extends_from(A) ::= T_EXTENDS fully_qualified_class_name(B). {A = new PHP_ParseryyToken(B, array(B));}
extends_from(A) ::= . {A = new PHP_ParseryyToken('');}

interface_entry ::= T_INTERFACE.

interface_extends_list ::= T_EXTENDS interface_list.
interface_extends_list ::= .

implements_list(A) ::= . {A = new PHP_ParseryyToken('');}
implements_list(A) ::= T_IMPLEMENTS interface_list(B). {A = B;}

interface_list(A) ::= fully_qualified_class_name(B). {A = new PHP_ParseryyToken('', array(B));}
interface_list(A) ::= interface_list(list) COMMA fully_qualified_class_name(B). {
    A = list;
    A[] = B;
}

expr(A) ::= r_variable(B). {A = B;}
expr(A) ::= expr_without_variable(B). {A = B;}

expr_without_variable(A) ::= T_LIST LPAREN assignment_list(B) RPAREN EQUALS expr(C). {
    A = new PHP_ParseryyToken('list(' . B->string . ') = ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= variable(VAR) EQUALS expr(E). {
    if ($this->lex->globalSearch(VAR->string)) {
        A = new PHP_ParseryyToken(VAR->string . ' = ' . E->string,
            array(
                'type' => 'global',
                'name' => VAR->string,
                'default' => E->string,
            ));
        A[] = VAR;
        A[] = E;
    } else {
        A = new PHP_ParseryyToken(VAR->string . ' = ' . E->string, VAR);
        A[] = E;
    }
}
expr_without_variable(A) ::= variable(VAR) EQUALS AMPERSAND variable(E).{
    if ($this->lex->globalSearch(VAR->string)) {
        A = new PHP_ParseryyToken(VAR->string . ' = ' . E->string,
            array(
                'type' => 'global',
                'name' => VAR->string,
                'default' => '&' . E->string,
            ));
        A[] = VAR;
        A[] = E;
    } else {
        A = new PHP_ParseryyToken(VAR->string . ' = &' . E->string, VAR);
        A[] = E;
    }
}

expr_without_variable(A) ::= variable(VAR) EQUALS AMPERSAND T_NEW class_name_reference(CL) ctor_arguments(ARGS). {
    $c = is_string(CL) ? CL : CL->string;
    if ($this->lex->globalSearch(VAR->string)) {
        A = new PHP_ParseryyToken(VAR->string . ' = &new ' . $c . ARGS->string,
            array(
                'type' => 'global',
                'name' => VAR->string,
                'default' => '&new ' . CL->string . ARGS->string,
            ));
        A[] = VAR;
    } else {
        A = new PHP_ParseryyToken(VAR->string . ' = &new ' . $c . ARGS->string, VAR);
    }
    if (is_string(CL)) {
        A[] = array('usedclass' => CL);
    }
    A[] = ARGS;
}
expr_without_variable(A) ::= T_NEW class_name_reference(B) ctor_arguments(C). {
    $b = is_string(B) ? B : B->string;
    A = new PHP_ParseryyToken('new ' . $b . C->string, B);
    A[] = C;
    if (is_string(B)) {
        A[] = array('uses' => 'class', 'name' => B);
    }
}
expr_without_variable(A) ::= T_CLONE expr(B). {
    A = new PHP_ParseryyToken('clone ' . B->string, B);
}
expr_without_variable(A) ::= variable(B) T_PLUS_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' += ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= variable(B) T_MINUS_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' -= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_MUL_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' *= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_DIV_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' /= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_CONCAT_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' .= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_MOD_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' %= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_AND_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' &= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_OR_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' |= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_XOR_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' ^= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_SL_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' <<= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= variable(B) T_SR_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' >>= ' . C->string, B);
    A[] = C;
}

expr_without_variable(A) ::= rw_variable(B) T_INC. {
    A = new PHP_ParseryyToken(B->string . '++', B);
}
expr_without_variable(A) ::= T_INC rw_variable(B). {
    A = new PHP_ParseryyToken('++' . B->string, B);
}
expr_without_variable(A) ::= rw_variable(B) T_DEC. {
    A = new PHP_ParseryyToken(B->string . '--', B);
}
expr_without_variable(A) ::= T_DEC rw_variable(B). {
    A = new PHP_ParseryyToken('--' . B->string, B);
}
expr_without_variable(A) ::= expr(B) T_BOOLEAN_OR expr(C). {
    A = new PHP_ParseryyToken(B->string . ' || ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_BOOLEAN_AND expr(C). {
    A = new PHP_ParseryyToken(B->string . ' && ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_LOGICAL_OR expr(C). {
    A = new PHP_ParseryyToken(B->string . ' OR ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_LOGICAL_AND expr(C). {
    A = new PHP_ParseryyToken(B->string . ' AND ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_LOGICAL_XOR expr(C). {
    A = new PHP_ParseryyToken(B->string . ' XOR ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) BAR expr(C). {
    A = new PHP_ParseryyToken(B->string . ' | ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) AMPERSAND expr(C). {
    A = new PHP_ParseryyToken(B->string . ' & ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) CARAT expr(C). {
    A = new PHP_ParseryyToken(B->string . ' ^ ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) DOT expr(C). {
    A = new PHP_ParseryyToken(B->string . ' . ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) PLUS expr(C). {
    A = new PHP_ParseryyToken(B->string . ' + ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) MINUS expr(C). {
    A = new PHP_ParseryyToken(B->string . ' - ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) TIMES expr(C). {
    A = new PHP_ParseryyToken(B->string . ' * ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) DIVIDE expr(C). {
    A = new PHP_ParseryyToken(B->string . ' / ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) PERCENT expr(C). {
    A = new PHP_ParseryyToken(B->string . ' % ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_SL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' << ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_SR expr(C). {
    A = new PHP_ParseryyToken(B->string . ' >> ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= PLUS expr(B). {
    A = new PHP_ParseryyToken('+' . B->string, B);
}
expr_without_variable(A) ::= MINUS expr(B). {
    A = new PHP_ParseryyToken('-' . B->string, B);
}
expr_without_variable(A) ::= EXCLAM expr(B). {
    A = new PHP_ParseryyToken('!' . B->string, B);
}
expr_without_variable(A) ::= TILDE expr(B). {
    A = new PHP_ParseryyToken('~' . B->string, B);
}
expr_without_variable(A) ::= expr(B) T_IS_IDENTICAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' === ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_IS_NOT_IDENTICAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' !== ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_IS_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' == ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_IS_NOT_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' != ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) LESSTHAN expr(C). {
    A = new PHP_ParseryyToken(B->string . ' < ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_IS_SMALLER_OR_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' <= ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) GREATERTHAN expr(C). {
    A = new PHP_ParseryyToken(B->string . ' > ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_IS_GREATER_OR_EQUAL expr(C). {
    A = new PHP_ParseryyToken(B->string . ' >= ' . C->string, B);
    A[] = C;
}
expr_without_variable(A) ::= expr(B) T_INSTANCEOF class_name_reference(CL). {
    $c = is_string(CL) ? CL : CL->string;
    A = new PHP_ParseryyToken(B->string . ' instanceof ' . $c, B);
    if (!is_string(CL)) {
        A[] = CL;
    }
}
expr_without_variable(A) ::= LPAREN expr(B) RPAREN. {
    A = new PHP_ParseryyToken('(' . B->string . ')', B);
}
expr_without_variable(A) ::= expr(B) QUESTION
		expr(C) COLON
		expr(D). {
    A = new PHP_ParseryyToken(B->string . ' ? ' . C->string . ' : ' . D->string, B);
    A[] = C;
    A[] = D;
}
expr_without_variable(A) ::= internal_functions_in_yacc(B). {A = B;}
expr_without_variable(A) ::= T_INT_CAST expr(B). {
    A = new PHP_ParseryyToken('(int) ' . B->string, B);
}
expr_without_variable(A) ::= T_DOUBLE_CAST expr(B). {
    A = new PHP_ParseryyToken('(double) ' . B->string, B);
}
expr_without_variable(A) ::= T_STRING_CAST expr(B). {
    A = new PHP_ParseryyToken('(string) ' . B->string, B);
}
expr_without_variable(A) ::= T_ARRAY_CAST expr(B). {
    A = new PHP_ParseryyToken('(array) ' . B->string, B);
}
expr_without_variable(A) ::= T_OBJECT_CAST expr(B). {
    A = new PHP_ParseryyToken('(object) ' . B->string, B);
}
expr_without_variable(A) ::= T_BOOL_CAST expr(B). {
    A = new PHP_ParseryyToken('(bool) ' . B->string, B);
}
expr_without_variable(A) ::= T_UNSET_CAST expr(B). {
    A = new PHP_ParseryyToken('(unset) ' . B->string, B);
}
expr_without_variable(A) ::= T_EXIT exit_expr(B). {
    A = new PHP_ParseryyToken('exit ' . B->string, B);
}
expr_without_variable(A) ::= AT expr(B). {
    A = new PHP_ParseryyToken('@' . B->string, B);
}
expr_without_variable(A) ::= scalar(B). {
    A = new PHP_ParseryyToken(B->string, B);
}
expr_without_variable(A) ::= expr_without_variable_t_array LPAREN array_pair_list(B) RPAREN. {
    A = new PHP_ParseryyToken('array(' . B->string . ')', B);
}
expr_without_variable(A) ::= BACKQUOTE encaps_list(B) BACKQUOTE. {
    A = new PHP_ParseryyToken('`' . B->string . '`');
}
expr_without_variable(A) ::= T_PRINT expr(B). {
    A = new PHP_ParseryyToken('print ' . B->string, B);
}

expr_without_variable_t_array ::= T_ARRAY. {$this->lex->trackWhitespace();}

exit_expr(A) ::= LPAREN RPAREN. {A = new PHP_ParseryyToken('()');}
exit_expr(A) ::= LPAREN expr(B) RPAREN. {A = new PHP_ParseryyToken('(' . B->string . ')', B);}
exit_expr(A) ::= . {A = new PHP_ParseryyToken('');}

common_scalar(A) ::=
		T_LNUMBER
	   |T_DNUMBER
	   |T_CONSTANT_ENCAPSED_STRING
	   |T_LINE
	   |T_FILE
	   |T_CLASS_C
	   |T_METHOD_C
	   |T_FUNC_C(B). {A = B;}

/* compile-time evaluated scalars */
static_scalar(A) ::= common_scalar(B). {A = B;}
static_scalar(A) ::= T_STRING(B). {A = B;}
static_scalar(A) ::= static_scalar_t_array(B) LPAREN(C) static_array_pair_list(D) RPAREN(E). {
    A = B . C . D . E;
    // have to do all because of nested arrays
    $this->lex->stopTrackingWhitespace(); // we only need whitespace for
                                          // array default values
}
static_scalar(A) ::= static_class_constant(B). {A = B;}

static_scalar_t_array(A) ::= T_ARRAY(B). {
    $this->lex->trackWhitespace();
    A = B;
}

static_array_pair_list(A) ::= non_empty_static_array_pair_list(B). {A = B;}
static_array_pair_list(A) ::= non_empty_static_array_pair_list(B) COMMA(C). {
    A = B . C;
}
static_array_pair_list(A) ::= . {A = '';}

non_empty_static_array_pair_list(A) ::= non_empty_static_array_pair_list(B) COMMA(C) static_scalar(D) T_DOUBLE_ARROW(E) static_scalar(F). {
    A = B . C . D . E . F;
}
non_empty_static_array_pair_list(A) ::= non_empty_static_array_pair_list(B) COMMA(C) static_scalar(D). {
    A = B . C . D;
}
non_empty_static_array_pair_list(A) ::= static_scalar(B) T_DOUBLE_ARROW(C) static_scalar(D). {
    A = B . C . D;
}
non_empty_static_array_pair_list(A) ::= static_scalar(B). {A = B;}

static_class_constant(A) ::= T_STRING(B) T_PAAMAYIM_NEKUDOTAYIM T_STRING(C). {
    A = B . '::' . C;
}

foreach_optional_arg ::= T_DOUBLE_ARROW foreach_variable.
foreach_optional_arg ::= .

foreach_variable ::= w_variable.
foreach_variable ::= AMPERSAND w_variable.

for_statement(A) ::= statement(B). {A = B;}
for_statement(A) ::= COLON inner_statement_list(B) T_ENDFOR SEMI. {A = B;}

foreach_statement(A) ::= statement(B). {A = B;}
foreach_statement(A) ::= COLON inner_statement_list(B) T_ENDFOREACH SEMI. {A = B;}


declare_statement(A) ::= statement(B). {A = B;}
declare_statement(A) ::= COLON inner_statement_list(B) T_ENDDECLARE SEMI. {A = B;}

declare_list(A) ::= T_STRING(B) EQUALS static_scalar(C). {
    A = new PHP_ParseryyToken(B . ' = ' . C, array('declare' => B, 'default' => C));
}
declare_list(A) ::= declare_list(DEC) COMMA T_STRING(B) EQUALS static_scalar(C). {
    A = new PHP_ParseryyToken(DEC->string . ', ' . B . ' = ' . C, DEC);
    A[] = array('declare' => B, 'default' => C);
}

switch_case_list(A) ::= LCURLY case_list(B) RCURLY. {A = B;}
switch_case_list(A) ::= LCURLY SEMI case_list(B) RCURLY. {A = B;}
switch_case_list(A) ::= COLON case_list(B) T_ENDSWITCH SEMI. {A = B;}
switch_case_list(A) ::= COLON SEMI case_list(B) T_ENDSWITCH SEMI. {A = B;}

case_list(A) ::= case_list(LIST) T_CASE expr(B) case_separator. {
    A = LIST;
    A[] = B;
}
case_list(A) ::= case_list(LIST) T_DEFAULT case_separator inner_statement_list(B). {
    A = LIST;
    A[] = B;
}
case_list(A) ::= . {A = new PHP_ParseryyToken('');}

case_separator ::= COLON|SEMI.

while_statement(A) ::= statement(B). {A = B;}
while_statement(A) ::= COLON inner_statement_list(B) T_ENDWHILE SEMI. {A = B;}

elseif_list(A) ::= elseif_list(B) T_ELSEIF LPAREN expr(C) RPAREN statement(D). {
    A = B;
    A[] = C;
    A[] = D;
}
elseif_list(A) ::= . {A = new PHP_ParseryyToken('');}

new_elseif_list(A) ::= new_elseif_list(B) T_ELSEIF LPAREN expr(C) RPAREN COLON inner_statement_list(D) . {
    A = B;
    A[] = C;
    A[] = D;
}
new_elseif_list(A) ::= . {A = new PHP_ParseryyToken('');}

else_single(A) ::= T_ELSE statement(B). {A = B;}
else_single(A) ::= . {A = new PHP_ParseryyToken('');}

new_else_single(A) ::= T_ELSE COLON inner_statement_list(B). {A = B;}
new_else_single(A) ::= . {A = new PHP_ParseryyToken('');}

parameter_list(A) ::= non_empty_parameter_list(B). {A = B;}
parameter_list(A) ::= . {A = new PHP_ParseryyToken('');}

non_empty_parameter_list(A) ::= optional_class_type(T) T_VARIABLE(V). {
    A = new PHP_ParseryyToken(T . V, array(
            array(
                'typehint' => T,
                'param' => V,
                'isreference' => false,
                'default' => null,
            )
        ));
}
non_empty_parameter_list(A) ::= optional_class_type(T) AMPERSAND T_VARIABLE(V). {
    A = new PHP_ParseryyToken(T . '&' . V, array(
            array(
                'typehint' => T,
                'param' => V,
                'isreference' => true,
                'default' => null,
            )
        ));
}
non_empty_parameter_list(A) ::= optional_class_type(T) AMPERSAND T_VARIABLE(V) EQUALS static_scalar(D). {
    A = new PHP_ParseryyToken(T . '&' . V . ' = ' . D, array(
            array(
                'typehint' => T,
                'param' => V,
                'isreference' => true,
                'default' => D,
            )
        ));
}
non_empty_parameter_list(A) ::= optional_class_type(T) T_VARIABLE(V) EQUALS static_scalar(D). {
    A = new PHP_ParseryyToken(T . V . ' = ' . D, array(
            array(
                'typehint' => T,
                'param' => V,
                'isreference' => false,
                'default' => D,
            )
        ));
}
non_empty_parameter_list(A) ::= non_empty_parameter_list(list) COMMA optional_class_type(T) T_VARIABLE(V). {
    A = new PHP_ParseryyToken(list->string . ', ' . T . V, list);
    A[] = 
        array(
            'typehint' => T,
            'param' => V,
            'isreference' => false,
            'default' => null,
        );
}
non_empty_parameter_list(A) ::= non_empty_parameter_list(list) COMMA optional_class_type(T) AMPERSAND T_VARIABLE(V). {
    A = new PHP_ParseryyToken(list->string . ', ' . T . '&' . V, list);
    A[] = 
        array(
            'typehint' => T,
            'param' => V,
            'isreference' => true,
            'default' => null,
        );
}
non_empty_parameter_list(A) ::= non_empty_parameter_list(list) COMMA optional_class_type(T) AMPERSAND T_VARIABLE(V) EQUALS static_scalar(D). {
    A = new PHP_ParseryyToken(list->string . ', ' . T . V . ' = ' . D, list);
    A[] = 
        array(
            'typehint' => T,
            'param' => V,
            'isreference' => true,
            'default' => D,
        );
}
non_empty_parameter_list(A) ::= non_empty_parameter_list(list) COMMA optional_class_type(T) T_VARIABLE(V) EQUALS static_scalar(D). {
    A = new PHP_ParseryyToken(list->string . ', ' . T . V . ' = ' . D, list);
    A[] = 
        array(
            'typehint' => T,
            'param' => V,
            'isreference' => false,
            'default' => D,
        );
}


optional_class_type(A) ::= T_STRING|T_ARRAY(B). {A = B;}
optional_class_type(A) ::= . {A = '';}

function_call_parameter_list(A) ::= non_empty_function_call_parameter_list(B). {A = B;}
function_call_parameter_list(A) ::= . {A = new PHP_ParseryyToken('');}

non_empty_function_call_parameter_list(A) ::= expr_without_variable(B). {A = new PHP_ParseryyToken(B);}
non_empty_function_call_parameter_list(A) ::= variable(B). {A = PHP_ParseryyToken(B);}
non_empty_function_call_parameter_list(A) ::= AMPERSAND w_variable(B). {
    if (B instanceof PHP_ParseryyToken) {
        $b = B->string;
    } else {
        $b = (string) B;
    }
    A = new PHP_ParseryyToken('&' . $b, B);}
non_empty_function_call_parameter_list(A) ::= non_empty_function_call_parameter_list(LIST) COMMA expr_without_variable(B). {
    if (B instanceof PHP_ParseryyToken) {
        $b = B->string;
    } else {
        $b = (string) B;
    }
    A = new PHP_ParseryyToken(LIST->string . ', ' . $b, LIST);
    A[] = B;
}
non_empty_function_call_parameter_list(A) ::= non_empty_function_call_parameter_list(LIST) COMMA variable(B). {
    if (B instanceof PHP_ParseryyToken) {
        $b = B->string;
    } else {
        $b = (string) B;
    }
    A = new PHP_ParseryyToken(LIST->string . ', ' . $b, LIST);
    A[] = B;
}
non_empty_function_call_parameter_list(A) ::= non_empty_function_call_parameter_list(LIST) COMMA AMPERSAND w_variable(B). {
    if (B instanceof PHP_ParseryyToken) {
        $b = B->string;
    } else {
        $b = (string) B;
    }
    A = new PHP_ParseryyToken(LIST->string . ', &' . $b, LIST);
    A[] = B;
}

global_var_list(A) ::= global_var_list(B) COMMA global_var(C). {
    A = B;
    A[] = C;
}
global_var_list(A) ::= global_var(B). {A = B;}

global_var(A) ::= T_VARIABLE(B). {A = new PHP_ParseryyToken(B, array('global' => B));}
global_var(A) ::= DOLLAR r_variable(B). {A = new PHP_ParseryyToken('$' . B);}
global_var(A) ::= DOLLAR LCURLY expr(B) RCURLY.{
    A = new PHP_ParseryyToken('${' . B->string . '}', B);
}


static_var_list(A) ::= static_var_list(B) COMMA T_VARIABLE(C). {
    A = B;
    A[] = array('static' => C, 'default' => null);
}
static_var_list(A) ::= static_var_list(B) COMMA T_VARIABLE(C) EQUALS static_scalar(D). {
    A = B;
    A[] = array('static' => C, 'default' => D);
}
static_var_list(A) ::= T_VARIABLE(B). {
    A = new PHP_ParseryyToken('', array('static' => B, 'default' => null));
}
static_var_list(A) ::= T_VARIABLE(B) EQUALS static_scalar(C). {
    A = new PHP_ParseryyToken('', array('static' => B, 'default' => C));
}

class_statement_list(A) ::= class_statement_list(list) class_statement(B). {
    A = list;
    A[] = B;
}
class_statement_list(A) ::= . {A = array();}

class_statement(A) ::= variable_modifiers(mod) class_variable_declaration(B) SEMI. {
    $a = array();
    foreach (B as $item) {
        $a[] = array(
            'type' => 'var',
            'name' => $item['name'],
            'default' => $item['default'],
            'modifiers' => mod,
        );
    }
    A = new PHP_ParseryyToken('', $a);
}
class_statement(A) ::= class_constant_declaration(B) SEMI. {
    $a = array();
    foreach (B as $item) {
        $a[] = array(
            'type' => 'const',
            'name' => $item['name'],
            'value' => $item['value'],
        );
    }
    A = new PHP_ParseryyToken('', $a);
}
class_statement(A) ::= method_modifiers(mod) T_FUNCTION is_reference T_STRING(B) LPAREN parameter_list(params) RPAREN method_body. {
    A = new PHP_ParseryyToken('', array(
            array(
                'type' => 'method',
                'name' => B,
                'parameters' => params->metadata,
                'modifiers' => mod,
            )
        ));
}


method_body(A) ::= SEMI. /* abstract method */ {A = new PHP_ParseryyToken('');}
method_body(A) ::= LCURLY inner_statement_list(B) RCURLY. {
    A = B;
}

variable_modifiers(A) ::= non_empty_member_modifiers(B). {A = B;}
variable_modifiers(A) ::= T_VAR. {A = array('public');}

method_modifiers(A) ::= non_empty_member_modifiers(B). {A = B;}
method_modifiers(A) ::= . {A = array('public');}

non_empty_member_modifiers(A) ::= member_modifier(B). {A = array(B);}
non_empty_member_modifiers(A) ::= non_empty_member_modifiers(mod) member_modifier(B). {
    A = mod;
    A[] = B;
}

member_modifier(A) ::= T_PUBLIC|T_PROTECTED|T_PRIVATE|T_STATIC|T_ABSTRACT|T_FINAL(B). {A = strtolower(B);}

class_variable_declaration(A) ::= class_variable_declaration(list) COMMA T_VARIABLE(var). {
    A = list;
    A[] = array(
        'name' => var,
        'default' => null,
    );
}
class_variable_declaration(A) ::= class_variable_declaration(list) COMMA T_VARIABLE(var) EQUALS static_scalar(val). {
    A = list;
    A[] = array(
        'name' => var,
        'default' => val,
    );
}
class_variable_declaration(A) ::= T_VARIABLE(B). {
    A = array(
            array(
                'name' => B,
                'default' => null,
            )
        );
}
class_variable_declaration(A) ::= T_VARIABLE(var) EQUALS static_scalar(val). {
    A = array(
            array(
                'name' => var,
                'default' => val,
            )
        );
}

class_constant_declaration(A) ::= class_constant_declaration(list) COMMA T_STRING(n) EQUALS static_scalar(v). {
    A = list;
    A[] = array('name' => n, 'value' => v);
}
class_constant_declaration(A) ::= T_CONST T_STRING(n) EQUALS static_scalar(v). {
    A = array(
        array('name' => n, 'value' => v)
    );
}

echo_expr_list(A) ::= echo_expr_list(B) COMMA expr(C). {A = B;A[] = C;}
echo_expr_list(A) ::= expr(B). {A = B;}

unset_variables(A) ::= unset_variable(B). {A = B;}
unset_variables(A) ::= unset_variables(B) COMMA unset_variable(C). {
    A = B;
    A[] = C;
}

unset_variable(A) ::= variable(B). {A = B;}

use_filename(A) ::= T_CONSTANT_ENCAPSED_STRING(B). {A = B;}
use_filename(A) ::= LCURLY T_CONSTANT_ENCAPSED_STRING(B) RCURLY. {
    A = '{' . B . '}';
}

r_variable(A) ::= variable(B). {A = B;}

w_variable(A) ::= variable(B). {A = B;}

rw_variable(A) ::= variable(B). {A = B;}

variable(A) ::= base_variable_with_function_calls(BASE) T_OBJECT_OPERATOR object_property(PROP) method_or_not(IS_METHOD) variable_properties(VARP). {
    A = new PHP_ParseryyToken((string) BASE . '->' . (string) PROP .
        (string) IS_METHOD . (string) VARP, array());
    A[] = BASE;
    if (is_array(PROP)) {
        A[] = PROP;
    } else {
        if (IS_METHOD->string) {
            A[] = array(
                'uses' => 'method',
                'name' => PROP,
            );
        } else {
            A[] = array(
                'uses' => 'var',
                'name' => PROP,
            );
        }
    }
    A[] = VARP;
}
variable(A) ::= base_variable_with_function_calls(B). {A = B;}

variable_properties(A) ::= variable_properties(B) variable_property(C).
variable_properties(A) ::= . {A = new PHP_ParseryyToken('');}

variable_property(A) ::= T_OBJECT_OPERATOR object_property(B) method_or_not(C). {
    A = new PHP_ParseryyToken('->' . B->string . C->string, B);
    A[] = C;
}

method_or_not(A) ::= LPAREN function_call_parameter_list(B) RPAREN. {
    A = new PHP_ParseryyToken('(' . B . ')', B);
}
method_or_not(A) ::= . {A = new PHP_ParseryyToken('');}

variable_without_objects(A) ::= reference_variable(B). {A = B;}
variable_without_objects(A) ::= simple_indirect_reference(I) reference_variable(B). {
    A = new PHP_ParseryyToken(I . B->string, B);
}

static_member(A) ::= fully_qualified_class_name(CLASS) T_PAAMAYIM_NEKUDOTAYIM variable_without_objects(VAR). {
    A = new PHP_ParseryyToken(CLASS . '::' . (string) VAR, array(
        array(
            'usedclass' => CLASS,
        )
    ));
    A[] = VAR;
}

base_variable_with_function_calls(A) ::= base_variable(B). {A = new PHP_ParseryyToken(B);}
base_variable_with_function_calls(A) ::= function_call(B). {A = B;}

base_variable(A) ::= reference_variable(B). {A = B;}
base_variable(A) ::= simple_indirect_reference(I) reference_variable(B). {
    A = new PHP_ParseryyToken(I . B->string, B);
}
base_variable(A) ::= static_member(B). {A = B;}
	
reference_variable(A) ::= reference_variable(REF) LBRACKET dim_offset(DIM) RBRACKET. {
    A = new PHP_ParseryyToken((string) REF . '[' . (string) DIM . ']', array());
    A[] = REF;
    A[] = DIM;
}
reference_variable(A) ::= reference_variable(REF) LCURLY expr(DIM) RCURLY. {
    A = new PHP_ParseryyToken((string) REF . '{' . (string) DIM . '}', array());
    A[] = REF;
    A[] = DIM;
}
reference_variable(A) ::= compound_variable(B). {A = new PHP_ParseryyToken(B);}

compound_variable(A) ::= T_VARIABLE(B). {A = B;}
compound_variable(A) ::= DOLLAR LCURLY expr(B) RCURLY. {A = new PHP_ParseryyToken('${' . (string) B . '}', B);}

dim_offset(A) ::= expr(B). {A = new PHP_ParseryyToken(B);}
dim_offset(A) ::= . {A = new PHP_ParseryyToken('');}

object_property(A) ::= object_dim_list(B). {A = B;}
object_property(A) ::= variable_without_objects(B). {A = B;}

object_dim_list(A) ::= object_dim_list(LIST) LBRACKET dim_offset(B) RBRACKET. {
    A = new PHP_ParseryyToken(LIST->string . '[' . B->string . ']', LIST);
    A[] = B;
}
object_dim_list(A) ::= object_dim_list(LIST) LCURLY expr(B) RCURLY. {
    A = new PHP_ParseryyToken(LIST->string . '{' . B->string . '}', LIST);
    A[] = B;
}
object_dim_list(A) ::= variable_name(B). {A = new PHP_ParseryyToken(B);}

variable_name(A) ::= T_STRING(B). {A = B;}
variable_name(A) ::= LCURLY expr(B) RCURLY. {A = new PHP_ParseryyToken('{' . B->string . '}', B);}

simple_indirect_reference(A) ::= DOLLAR. {A = '$';}
simple_indirect_reference(A) ::= simple_indirect_reference(B) DOLLAR. {A = B . '$';}

assignment_list(A) ::= assignment_list(B) COMMA assignment_list_element(C). {
    A = new PHP_ParseryyToken(B->string . ', ' . C->string, B);
    A[] = C;
}
assignment_list(A) ::= assignment_list_element(B). {A = B;}

assignment_list_element(A) ::= variable(B). {A = B;}
assignment_list_element(A) ::= T_LIST LPAREN assignment_list(B) RPAREN. {
    A = new PHP_ParseryyToken('list(' . B->string . ')', B);
}
assignment_list_element(A) ::= . {A = new PHP_ParseryyToken('');}

array_pair_list(A) ::= non_empty_array_pair_list(B) possible_comma(C). {
    A = new PHP_ParseryyToken(B->string . C, B);
}
array_pair_list(A) ::= . {A = new PHP_ParseryyToken('');}

non_empty_array_pair_list(A) ::= expr(B) T_DOUBLE_ARROW AMPERSAND w_variable(C). {
    A = new PHP_ParseryyToken(B->string . ' => &' . C->string, B);
    A[] = C;
}
non_empty_array_pair_list(A) ::= expr(B). {A = B;}
non_empty_array_pair_list(A) ::= AMPERSAND w_variable(B). {
    A = new PHP_ParseryyToken('&' . B->string, B);
}
non_empty_array_pair_list(A) ::= non_empty_array_pair_list(B) COMMA expr(C) T_DOUBLE_ARROW expr(D). {
    A = new PHP_ParseryyToken(B->string . ', ' . C->string . ' => ' . D->string, B);
    A[] = C;
    A[] = D;
}
non_empty_array_pair_list(A) ::= non_empty_array_pair_list(B) COMMA expr(C). {
    A = new PHP_ParseryyToken(B->string . ', ' . C->string, B);
    A[] = C;
}
non_empty_array_pair_list(A) ::= expr(B) T_DOUBLE_ARROW expr(C). {
    A = new PHP_ParseryyToken(B->string . ' => ' . C->string, B);
    A[] = C;
}
non_empty_array_pair_list(A) ::= non_empty_array_pair_list(B) COMMA expr(C) T_DOUBLE_ARROW AMPERSAND w_variable(D). {
    A = new PHP_ParseryyToken(B->string . ', ' . C->string . ' => &' . D->string, B);
    A[] = C;
    A[] = D;
}
non_empty_array_pair_list(A) ::= non_empty_array_pair_list(B) COMMA AMPERSAND w_variable(C). {
    A = new PHP_ParseryyToken(B->string . ', &' . C->string, B);
    A[] = C;
}


encaps_list(A) ::= encaps_list(B) encaps_var(C). {
    A = new PHP_ParseryyToken(B->string . C, B);
    A[] = C;
}
encaps_list(A) ::= encaps_list(B) T_STRING(C). {
    A = new PHP_ParseryyToken(B->string . C, B);
}
encaps_list(A) ::= encaps_list(B) T_NUM_STRING(C). {
    A = new PHP_ParseryyToken(B->string . C, B);
}
encaps_list(A) ::= encaps_list(B) T_ENCAPSED_AND_WHITESPACE(C). {
    A = new PHP_ParseryyToken(B->string . C, B);
}
encaps_list(A) ::= encaps_list(B) T_CHARACTER(C). {
    A = new PHP_ParseryyToken(B->string . C, B);
}
encaps_list(A) ::= encaps_list(B) T_BAD_CHARACTER(C). {
    A = new PHP_ParseryyToken(B->string . C, B);
}
encaps_list(A) ::= encaps_list(B) LBRACKET. {
    A = new PHP_ParseryyToken(B->string . '[', B);
}
encaps_list(A) ::= encaps_list(B) RBRACKET. {
    A = new PHP_ParseryyToken(B->string . ']', B);
}
encaps_list(A) ::= encaps_list(B) LCURLY. {
    A = new PHP_ParseryyToken(B->string . '{', B);
}
encaps_list(A) ::= encaps_list(B) RCURLY. {
    A = new PHP_ParseryyToken(B->string . '}', B);
}
encaps_list(A) ::= encaps_list(B) T_OBJECT_OPERATOR. {
    A = new PHP_ParseryyToken(B->string . '->', B);
}
encaps_list(A) ::= . {A = new PHP_ParseryyToken('');}

encaps_var(A) ::= T_VARIABLE(B). {A = new PHP_ParseryyToken(B);}
encaps_var(A) ::= T_VARIABLE(B) LBRACKET T_STRING|T_NUM_STRING|T_VARIABLE(C) RBRACKET. {
    A = new PHP_ParseryyToken(B . '[' . C . ']');
}
encaps_var(A) ::= T_VARIABLE(B) T_OBJECT_OPERATOR T_STRING(C). {
    A = new PHP_ParseryyToken(B . '->' . C);
}
encaps_var(A) ::= T_DOLLAR_OPEN_CURLY_BRACES expr(B) RCURLY. {
    A = new PHP_ParseryyToken('${' . B->string . '}', B);
}
encaps_var(A) ::= T_DOLLAR_OPEN_CURLY_BRACES T_STRING_VARNAME(B) LBRACKET expr(C) RBRACKET RCURLY. {
    A = new PHP_ParseryyToken('${' . B . '[' . C->string . ']}', C);
}
encaps_var(A) ::= T_CURLY_OPEN variable(B) RCURLY. {
    A = new PHP_ParseryyToken('{' . B->string, '}', B);
}

internal_functions_in_yacc(A) ::= T_ISSET LPAREN isset_variables(B) RPAREN. {
    A = new PHP_ParseryyToken('isset(' . B->string . ')', B);
}
internal_functions_in_yacc(A) ::= T_EMPTY LPAREN variable(B) RPAREN. {
    A = new PHP_ParseryyToken('empty(' . B->string . ')', B);
}
internal_functions_in_yacc(A) ::= T_INCLUDE expr(B). {
    A = new PHP_ParseryyToken('include ' . B->string, B);
    A[] = array(
        'type' => 'include',
        'file' => B->string,
    );
}
internal_functions_in_yacc(A) ::= T_INCLUDE_ONCE expr(B). {
    A = new PHP_ParseryyToken('include_once ' . B->string, B);
    A[] = array(
        'type' => 'include_once',
        'file' => B->string,
    );
}
internal_functions_in_yacc(A) ::= T_EVAL LPAREN expr(B) RPAREN. {
    A = new PHP_ParseryyToken('eval ' . B->string, B);
}
internal_functions_in_yacc(A) ::= T_REQUIRE expr(B). {
    A = new PHP_ParseryyToken('require ' . B->string, B);
    A[] = array(
        'type' => 'require',
        'file' => B->string,
    );
}
internal_functions_in_yacc(A) ::= T_REQUIRE_ONCE expr(B). {
    A = new PHP_ParseryyToken('require_once ' . B->string, B);
    A[] = array(
        'type' => 'require_once',
        'file' => B->string,
    );
}

isset_variables(A) ::= variable(B). {A = B;}
isset_variables(A) ::= isset_variables(B) COMMA variable(C). {
    A = new PHP_ParseryyToken(B->string . ', ' . C->string, B);
    A[] = C;
}

class_constant(A) ::= fully_qualified_class_name(B) T_PAAMAYIM_NEKUDOTAYIM T_STRING(C). {
    A = new PHP_ParseryyToken(B . '::' . C, array('usedclass' => B));
    A[] = array('usedclassconstant' => B . '::' . C);
}

fully_qualified_class_name(A) ::= T_STRING(B). {A = B;}

function_call(A) ::= T_STRING(B) LPAREN function_call_parameter_list(C) RPAREN. {A = new PHP_ParseryyToken(B . '(' . (string) C . ')', C);}
function_call(A) ::= fully_qualified_class_name(CLAS) T_PAAMAYIM_NEKUDOTAYIM T_STRING(FUNC) LPAREN function_call_parameter_list(PL) RPAREN. {
    A = new PHP_ParseryyToken(CLAS . '::' . FUNC . '(' . PL->string . ')',
            PL);
    A[] = array(
        'uses' => 'class',
        'name' => CLAS,
    );
    A[] = array(
        'uses' => 'method',
        'class' => CLAS,
        'name' => FUNC,
    );
}
function_call(A) ::= fully_qualified_class_name(CLAS) T_PAAMAYIM_NEKUDOTAYIM variable_without_objects(V) LPAREN function_call_parameter_list(PL) RPAREN. {
    A = new PHP_ParseryyToken(CLAS . '::' . (string) V . '(' . PL->string . ')', V);
    A[] = PL;
    A[] = array(
        'uses' => 'class',
        'name' => CLAS,
    );
}
function_call(A) ::= variable_without_objects(B) LPAREN function_call_parameter_list(PL) RPAREN. {
    A = new PHP_ParseryyToken((string) B . '(' . PL->string . ')', B);
    A[] = PL;
}

scalar(A) ::= T_STRING(B). {A = new PHP_ParseryyToken(B);}
scalar(A) ::= T_STRING_VARNAME(B). {A = new PHP_ParseryyToken(B);}
scalar(A) ::= class_constant(B). {A = new PHP_ParseryyToken(B);}
scalar(A) ::= common_scalar(B). {A = new PHP_ParseryyToken(B);}
scalar(A) ::= DOUBLEQUOTE encaps_list(B) DOUBLEQUOTE. {
    A = new PHP_ParseryyToken('"' . B->string . '"', B);
}
scalar(A) ::= SINGLEQUOTE encaps_list(B) SINGLEQUOTE. {
    A = new PHP_ParseryyToken("'" . B->string . "'", B);
}
scalar(A) ::= T_START_HEREDOC(HERE) encaps_list(B) T_END_HEREDOC(DOC). {
    A = new PHP_ParseryyToken(HERE->string . B->string . DOC->string, B);
}

class_name_reference(A) ::= T_STRING(B). {A = B;}
class_name_reference(A) ::= dynamic_class_name_reference(B). {A = B;}

dynamic_class_name_reference(A) ::= base_variable(B) T_OBJECT_OPERATOR object_property(C) dynamic_class_name_variable_properties(D). {
    A = new PHP_ParseryyToken(B->string . '->' . C->string . D->string, B);
    A[] = array('usedmember' => array(B->string, C->string));
    A[] = D;
}
dynamic_class_name_reference(A) ::= base_variable(B). {A = B;}

dynamic_class_name_variable_properties(A) ::= dynamic_class_name_variable_properties(B) dynamic_class_name_variable_property(C). {
    A = B;
    B[] = C;
}
dynamic_class_name_variable_properties(A) ::= . {A = new PHP_ParseryyToken('');}

dynamic_class_name_variable_property(A) ::= T_OBJECT_OPERATOR object_property(B). {
    A = new PHP_ParseryyToken('->' . B->string, array('usedmember' => B->string));
}

ctor_arguments(A) ::= LPAREN function_call_parameter_list(B) RPAREN. {
    A = new PHP_ParseryyToken('(' . B->string . ')', B);
}
ctor_arguments(A) ::= . {A = new PHP_ParseryyToken('');}

possible_comma(A) ::= COMMA. {A = ',';}
possible_comma(A) ::= . {A = '';}

for_expr(A) ::= non_empty_for_expr(B). {A = B;}
for_expr(A) ::= . {A = new PHP_ParseryyToken('');}

non_empty_for_expr(A) ::= non_empty_for_expr(B) COMMA expr(C). {
    A = new PHP_ParseryyToken(B->string . ', ' . C->string, B);
    A[] = C;
}
non_empty_for_expr(A) ::= expr(B). {A = B;}

is_reference(A) ::= AMPERSAND. {A = true;}
is_reference(A) ::= . {A = false;}
