#!/usr/local/bin/ruby -w

begin
  require 'rubygems'
  require_gem 'RubyInline'
rescue LoadError
  require "inline"
end

##
# ParseTree is a RubyInline-style extension that accesses and
# traverses the internal parse tree created by ruby.
#
#   class Example
#     def blah
#       return 1 + 1
#     end
#   end
#
#   ParseTree.new.parse_tree(Example)
#   =>  [[:defn,
#         "blah",
#         [:scope,
#          [:block,
#           [:args],
#            [:return, [:call, [:lit, 1], "+", [:array, [:lit, 1]]]]]]]]

class ParseTree

  VERSION = '1.3.0'

  ##
  # Initializes a ParseTree instance. Includes newline nodes if
  # +include_newlines+ which defaults to +$DEBUG+.

  def initialize(include_newlines=$DEBUG)
    @include_newlines = include_newlines
  end

  ##
  # Main driver for ParseTree. Returns an array of arrays containing
  # the parse tree for +klasses+.
  #
  # Structure:
  #
  #   [[:class, classname, superclassname, [:defn :method1, ...], ...], ...]
  #
  # NOTE: v1.0 - v1.1 had the signature (klass, meth=nil). This wasn't
  # used much at all and since parse_tree_for_method already existed,
  # it was deemed more useful to expand this method to do multiple
  # classes.

  def parse_tree(*klasses)
    result = []
    klasses.each do |klass|
      raise "You should call parse_tree_for_method(#{klasses.first}, #{klass}) instead of parse_tree" if Symbol === klass or String === klass
      klassname = klass.name
      klassname = "UnnamedClass_#{klass.object_id}" if klassname.empty?
      klassname = klassname.to_sym

      code = if Class === klass then
               superclass = klass.superclass.name
               superclass = "nil" if superclass.empty?
               superclass = superclass.to_sym
               [:class, klassname, superclass]
             else
               [:module, klassname]
             end

      klass.instance_methods(false).sort.each do |m|
        $stderr.puts "parse_tree_for_method(#{klass}, #{m}):" if $DEBUG
        code << parse_tree_for_method(klass, m.to_sym)
      end
      result << code
    end
    return result
  end

  ##
  # Returns the parse tree for just one +method+ of a class +klass+.
  #
  # Format:
  #
  #   [:defn, :name, :body]

  def parse_tree_for_method(klass, method)
    parse_tree_for_meth(klass, method.to_sym, @include_newlines)
  end

  inline do |builder|
    builder.add_type_converter("VALUE", '', '')
    builder.add_type_converter("ID *", '', '')
    builder.add_type_converter("NODE *", '(NODE *)', '(VALUE)')
    builder.include '"intern.h"'
    builder.include '"node.h"'
    builder.include '"st.h"'
    builder.include '"env.h"'
    builder.add_compile_flags "-Wall"
    builder.add_compile_flags "-W"
    builder.add_compile_flags "-Wpointer-arith"
    builder.add_compile_flags "-Wcast-qual"
    builder.add_compile_flags "-Wcast-align"
    builder.add_compile_flags "-Wwrite-strings"
    builder.add_compile_flags "-Wmissing-noreturn"
    builder.add_compile_flags "-Werror"
    # NOTE: this flag doesn't work w/ gcc 2.95.x - the FreeBSD default
    # builder.add_compile_flags "-Wno-strict-aliasing"
    # ruby.h screws these up hardcore:
    # builder.add_compile_flags "-Wundef"
    # builder.add_compile_flags "-Wconversion"
    # builder.add_compile_flags "-Wstrict-prototypes"
    # builder.add_compile_flags "-Wmissing-prototypes"
    # builder.add_compile_flags "-Wsign-compare", 

    builder.prefix %q{
        #define nd_3rd   u3.node

        struct METHOD {
          VALUE klass, rklass;
          VALUE recv;
          ID id, oid;
          NODE *body;
        };

        struct BLOCK {
          NODE *var;
          NODE *body;
          VALUE self;
          struct FRAME frame;
          struct SCOPE *scope;
          VALUE klass;
          NODE *cref;
          int iter;
          int vmode;
          int flags;
          int uniq;
          struct RVarmap *dyna_vars;
          VALUE orig_thread;
          VALUE wrapper;
          VALUE block_obj;
          struct BLOCK *outer;
          struct BLOCK *prev;
        };

        static char node_type_string[][60] = {
	  //  00
	  "method", "fbody", "cfunc", "scope", "block",
	  "if", "case", "when", "opt_n", "while",
	  //  10
	  "until", "iter", "for", "break", "next",
	  "redo", "retry", "begin", "rescue", "resbody",
	  //  20
	  "ensure", "and", "or", "not", "masgn",
	  "lasgn", "dasgn", "dasgn_curr", "gasgn", "iasgn",
	  //  30
	  "cdecl", "cvasgn", "cvdecl", "op_asgn1", "op_asgn2",
	  "op_asgn_and", "op_asgn_or", "call", "fcall", "vcall",
	  //  40
	  "super", "zsuper", "array", "zarray", "hash",
	  "return", "yield", "lvar", "dvar", "gvar",
	  //  50
	  "ivar", "const", "cvar", "nth_ref", "back_ref",
	  "match", "match2", "match3", "lit", "str",
	  //  60
	  "dstr", "xstr", "dxstr", "evstr", "dregx",
	  "dregx_once", "args", "argscat", "argspush", "splat",
	  //  70
	  "to_ary", "svalue", "block_arg", "block_pass", "defn",
	  "defs", "alias", "valias", "undef", "class",
	  //  80
	  "module", "sclass", "colon2", "colon3", "cref",
	  "dot2", "dot3", "flip2", "flip3", "attrset",
	  //  90
	  "self", "nil", "true", "false", "defined",
	  //  95
	  "newline", "postexe",
#ifdef C_ALLOCA
	  "alloca",
#endif
	  "dmethod", "bmethod",
	  // 100 / 99
	  "memo", "ifunc", "dsym", "attrasgn",
	  // 104 / 103
	  "last" 
        };
  }

    builder.c_raw %q^
static void add_to_parse_tree(VALUE ary,
                              NODE * n,
                              VALUE newlines,
                              ID * locals) {
  NODE * volatile node = n;
  NODE * volatile contnode = NULL;
  VALUE old_ary = Qnil;
  VALUE current;
  VALUE node_name;

  if (!node) return;

again:

  if (node) {
    node_name = ID2SYM(rb_intern(node_type_string[nd_type(node)]));
    if (RTEST(ruby_debug)) {
      fprintf(stderr, "%15s: %s%s%s\n",
        node_type_string[nd_type(node)],
        (RNODE(node)->u1.node != NULL ? "u1 " : "   "),
        (RNODE(node)->u2.node != NULL ? "u2 " : "   "),
        (RNODE(node)->u3.node != NULL ? "u3 " : "   "));
    }
  } else {
    node_name = ID2SYM(rb_intern("ICKY"));
  }

  current = rb_ary_new();
  rb_ary_push(ary, current);
  rb_ary_push(current, node_name);

again_no_block:

    switch (nd_type(node)) {

    case NODE_BLOCK:
      if (contnode) {
        add_to_parse_tree(current, node, newlines, locals);
        break;
      }

      contnode = node->nd_next;

      // NOTE: this will break the moment there is a block w/in a block
      old_ary = ary;
      ary = current;
      node = node->nd_head;
      goto again;
      break;

    case NODE_FBODY:
    case NODE_DEFINED:
      add_to_parse_tree(current, node->nd_head, newlines, locals);
      break;

    case NODE_COLON2:
      add_to_parse_tree(current, node->nd_head, newlines, locals);
      rb_ary_push(current, ID2SYM(node->nd_mid));
      break;

    case NODE_BEGIN:
      node = node->nd_body;
      goto again;

    case NODE_MATCH2:
    case NODE_MATCH3:
      add_to_parse_tree(current, node->nd_recv, newlines, locals);
      add_to_parse_tree(current, node->nd_value, newlines, locals);
      break;

    case NODE_OPT_N:
      add_to_parse_tree(current, node->nd_body, newlines, locals);
      break;

    case NODE_IF:
      add_to_parse_tree(current, node->nd_cond, newlines, locals);
      if (node->nd_body) {
        add_to_parse_tree(current, node->nd_body, newlines, locals);
      } else {
        rb_ary_push(current, Qnil);
      }
      if (node->nd_else) {
        add_to_parse_tree(current, node->nd_else, newlines, locals);
      } else {
        rb_ary_push(current, Qnil);
      }
      break;

  case NODE_CASE:
    add_to_parse_tree(current, node->nd_head, newlines, locals); /* expr */
    node = node->nd_body;
    while (node) {
      add_to_parse_tree(current, node, newlines, locals);
      if (nd_type(node) == NODE_WHEN) {                 /* when */
        node = node->nd_next; 
      } else {
        break;                                          /* else */
      }
      if (! node) {
        rb_ary_push(current, Qnil);                     /* no else */
      }
    }
    break;

  case NODE_WHEN:
    add_to_parse_tree(current, node->nd_head, newlines, locals); /* args */
    if (node->nd_body) {
      add_to_parse_tree(current, node->nd_body, newlines, locals); /* body */
    } else {
      rb_ary_push(current, Qnil);
    }
    break;

  case NODE_WHILE:
  case NODE_UNTIL:
    add_to_parse_tree(current,  node->nd_cond, newlines, locals);
    add_to_parse_tree(current,  node->nd_body, newlines, locals); 
    break;

  case NODE_BLOCK_PASS:
    add_to_parse_tree(current, node->nd_body, newlines, locals);
    add_to_parse_tree(current, node->nd_iter, newlines, locals);
    break;

  case NODE_ITER:
  case NODE_FOR:
    add_to_parse_tree(current, node->nd_iter, newlines, locals);
    if (node->nd_var != (NODE *)1
        && node->nd_var != (NODE *)2
        && node->nd_var != NULL) {
      add_to_parse_tree(current, node->nd_var, newlines, locals);
    } else {
      rb_ary_push(current, Qnil);
    }
    add_to_parse_tree(current, node->nd_body, newlines, locals);
    break;

  case NODE_BREAK:
  case NODE_NEXT:
  case NODE_YIELD:
    if (node->nd_stts)
      add_to_parse_tree(current, node->nd_stts, newlines, locals);
    break;

  case NODE_RESCUE:
      add_to_parse_tree(current, node->nd_1st, newlines, locals);
      add_to_parse_tree(current, node->nd_2nd, newlines, locals);
    break;

  case NODE_RESBODY:            // stmt rescue stmt | a = b rescue c - no repro
      add_to_parse_tree(current, node->nd_3rd, newlines, locals);
      add_to_parse_tree(current, node->nd_2nd, newlines, locals);
      add_to_parse_tree(current, node->nd_1st, newlines, locals);
    break;
	
  case NODE_ENSURE:
    add_to_parse_tree(current, node->nd_head, newlines, locals);
    if (node->nd_ensr) {
      add_to_parse_tree(current, node->nd_ensr, newlines, locals);
    }
    break;

  case NODE_AND:
  case NODE_OR:
    add_to_parse_tree(current, node->nd_1st, newlines, locals);
    add_to_parse_tree(current, node->nd_2nd, newlines, locals);
    break;

  case NODE_NOT:
    add_to_parse_tree(current, node->nd_body, newlines, locals);
    break;

  case NODE_DOT2:
  case NODE_DOT3:
  case NODE_FLIP2:
  case NODE_FLIP3:
    add_to_parse_tree(current, node->nd_beg, newlines, locals);
    add_to_parse_tree(current, node->nd_end, newlines, locals);
    break;

  case NODE_RETURN:
    if (node->nd_stts)
      add_to_parse_tree(current, node->nd_stts, newlines, locals);
    break;

  case NODE_ARGSCAT:
  case NODE_ARGSPUSH:
    add_to_parse_tree(current, node->nd_head, newlines, locals);
    add_to_parse_tree(current, node->nd_body, newlines, locals);
    break;

  case NODE_CALL:
  case NODE_FCALL:
  case NODE_VCALL:
    if (nd_type(node) != NODE_FCALL)
      add_to_parse_tree(current, node->nd_recv, newlines, locals);
    rb_ary_push(current, ID2SYM(node->nd_mid));
    if (node->nd_args || nd_type(node) != NODE_FCALL)
      add_to_parse_tree(current, node->nd_args, newlines, locals);
    break;

  case NODE_SUPER:
    add_to_parse_tree(current, node->nd_args, newlines, locals);
    break;

  case NODE_BMETHOD:
    {
      struct BLOCK *data;
      Data_Get_Struct(node->nd_cval, struct BLOCK, data);
      add_to_parse_tree(current, data->var, newlines, locals);
      add_to_parse_tree(current, data->body, newlines, locals);
      break;
    }
    break;

  case NODE_DMETHOD:
    {
      struct METHOD *data;
      Data_Get_Struct(node->nd_cval, struct METHOD, data);
      rb_ary_push(current, ID2SYM(data->id));
      add_to_parse_tree(current, data->body, newlines, locals);
      break;
    }

  case NODE_METHOD:
    fprintf(stderr, "u1 = %p u2 = %p u3 = %p\n", node->nd_1st, node->nd_2nd, node->nd_3rd);
    add_to_parse_tree(current, node->nd_3rd, newlines, locals);
    break;

  case NODE_SCOPE:
    add_to_parse_tree(current, node->nd_next, newlines, node->nd_tbl);
    break;

  case NODE_OP_ASGN1:
    add_to_parse_tree(current, node->nd_recv, newlines, locals);
    add_to_parse_tree(current, node->nd_args->nd_next, newlines, locals);
    add_to_parse_tree(current, node->nd_args->nd_head, newlines, locals);
    break;

  case NODE_OP_ASGN2:
    add_to_parse_tree(current, node->nd_recv, newlines, locals);
    add_to_parse_tree(current, node->nd_value, newlines, locals);
    break;

  case NODE_OP_ASGN_AND:
  case NODE_OP_ASGN_OR:
    add_to_parse_tree(current, node->nd_head, newlines, locals);
    add_to_parse_tree(current, node->nd_value, newlines, locals);
    break;

  case NODE_MASGN:
    add_to_parse_tree(current, node->nd_head, newlines, locals);
    if (node->nd_args) {
      if (node->nd_args != (NODE *)-1) {
	add_to_parse_tree(current, node->nd_args, newlines, locals);
      }
    }
    add_to_parse_tree(current, node->nd_value, newlines, locals);
    break;

  case NODE_LASGN:
  case NODE_IASGN:
  case NODE_DASGN:
  case NODE_DASGN_CURR:
  case NODE_CDECL:
  case NODE_CVASGN:
  case NODE_CVDECL:
  case NODE_GASGN:
    rb_ary_push(current, ID2SYM(node->nd_vid));
    add_to_parse_tree(current, node->nd_value, newlines, locals);
    break;

  case NODE_ALIAS:            // u1 u2 (alias :blah :blah2)
  case NODE_VALIAS:           // u1 u2 (alias $global $global2)
    rb_ary_push(current, ID2SYM(node->u1.id));
    rb_ary_push(current, ID2SYM(node->u2.id));
    break;

  case NODE_COLON3:           // u2    (::OUTER_CONST)
  case NODE_UNDEF:            // u2    (undef instvar)
    rb_ary_push(current, ID2SYM(node->u2.id));
    break;

  case NODE_HASH:
    {
      NODE *list;
	
      list = node->nd_head;
      while (list) {
	add_to_parse_tree(current, list->nd_head, newlines, locals);
	list = list->nd_next;
	if (list == 0)
	  rb_bug("odd number list for Hash");
	add_to_parse_tree(current, list->nd_head, newlines, locals);
	list = list->nd_next;
      }
    }
    break;

  case NODE_ARRAY:
      while (node) {
	add_to_parse_tree(current, node->nd_head, newlines, locals);
        node = node->nd_next;
      }
    break;

  case NODE_DSTR:
  case NODE_DXSTR:
  case NODE_DREGX:
  case NODE_DREGX_ONCE:
    {
      NODE *list = node->nd_next;
      if (nd_type(node) == NODE_DREGX || nd_type(node) == NODE_DREGX_ONCE) {
	break;
      }
      rb_ary_push(current, rb_str_new3(node->nd_lit));
      while (list) {
	if (list->nd_head) {
	  switch (nd_type(list->nd_head)) {
	  case NODE_STR:
	    add_to_parse_tree(current, list->nd_head, newlines, locals);
	    break;
	  case NODE_EVSTR:
	    add_to_parse_tree(current, list->nd_head->nd_body, newlines, locals);
	    break;
	  default:
	    add_to_parse_tree(current, list->nd_head, newlines, locals);
	    break;
	  }
	}
	list = list->nd_next;
      }
    }
    break;

  case NODE_DEFN:
  case NODE_DEFS:
    if (node->nd_defn) {
      if (nd_type(node) == NODE_DEFS)
	add_to_parse_tree(current, node->nd_recv, newlines, locals);
      rb_ary_push(current, ID2SYM(node->nd_mid));
      add_to_parse_tree(current, node->nd_defn, newlines, locals);
    }
    break;

  case NODE_CLASS:
  case NODE_MODULE:
    rb_ary_push(current, ID2SYM((ID)node->nd_cpath->nd_mid));
    if (node->nd_super && nd_type(node) == NODE_CLASS) {
      add_to_parse_tree(current, node->nd_super, newlines, locals);
    }
    add_to_parse_tree(current, node->nd_body, newlines, locals);
    break;

  case NODE_SCLASS:
    add_to_parse_tree(current, node->nd_recv, newlines, locals);
    add_to_parse_tree(current, node->nd_body, newlines, locals);
    break;

  case NODE_ARGS:
    if (locals && 
	(node->nd_cnt || node->nd_opt || node->nd_rest != -1)) {
      int i;
      NODE *optnode;
      long arg_count;

      for (i = 0; i < node->nd_cnt; i++) {
        // regular arg names
        rb_ary_push(current, ID2SYM(locals[i + 3]));
      }

      optnode = node->nd_opt;
      while (optnode) {
        // optional arg names
        rb_ary_push(current, ID2SYM(locals[i + 3]));
	i++;
	optnode = optnode->nd_next;
      }

      arg_count = node->nd_rest;
      if (arg_count > 0) {
        // *arg name
        rb_ary_push(current, ID2SYM(locals[node->nd_rest + 1]));
      } else if (arg_count == -1) {
        // nothing to do in this case, handled above
      } else if (arg_count == -2) {
        // nothing to do in this case, no name == no use
      } else {
        puts("not a clue what this arg value is");
        exit(1);
      }

      optnode = node->nd_opt;
      // block?
      if (optnode) {
	add_to_parse_tree(current, node->nd_opt, newlines, locals);
      }
    }
    break;
	
  case NODE_LVAR:
  case NODE_DVAR:
  case NODE_IVAR:
  case NODE_CVAR:
  case NODE_GVAR:
  case NODE_CONST:
  case NODE_ATTRSET:
    rb_ary_push(current, ID2SYM(node->nd_vid));
    break;

  case NODE_XSTR:             // u1    (%x{ls})
  case NODE_STR:              // u1
  case NODE_LIT:
  case NODE_MATCH:
    rb_ary_push(current, node->nd_lit);
    break;

  case NODE_NEWLINE:
    rb_ary_push(current, INT2FIX(nd_line(node)));
    rb_ary_push(current, rb_str_new2(node->nd_file));

    if (! RTEST(newlines)) rb_ary_pop(ary); // nuke it

    node = node->nd_next;
    goto again;
    break;

  case NODE_NTH_REF:          // u2 u3 ($1) - u3 is local_cnt('~') ignorable?
    rb_ary_push(current, INT2FIX(node->nd_nth));
    break;

  case NODE_BACK_REF:         // u2 u3 ($& etc)
    {
    char c = node->nd_nth;
    rb_ary_push(current, rb_str_intern(rb_str_new(&c, 1)));
    }
    break;

  case NODE_BLOCK_ARG:        // u1 u3 (def x(&b)
    rb_ary_push(current, ID2SYM(node->u1.id));
    break;

  // these nodes are empty and do not require extra work:
  case NODE_RETRY:
  case NODE_FALSE:
  case NODE_NIL:
  case NODE_SELF:
  case NODE_TRUE:
  case NODE_ZARRAY:
  case NODE_ZSUPER:
  case NODE_REDO:
    break;

  case NODE_SPLAT:
  case NODE_TO_ARY:
  case NODE_SVALUE:             // a = b, c
    add_to_parse_tree(current, node->nd_head, newlines, locals);
    break;

  case NODE_ATTRASGN:           // literal.meth = y u1 u2 u3
    // node id node
    add_to_parse_tree(current, node->nd_1st, newlines, locals);
    rb_ary_push(current, ID2SYM(node->u2.id));
    add_to_parse_tree(current, node->nd_3rd, newlines, locals);
    break;

  case NODE_DSYM:               // :"#{foo}" u1 u2 u3
    add_to_parse_tree(current, node->nd_3rd, newlines, locals);
    break;

  case NODE_EVSTR:
    add_to_parse_tree(current, node->nd_2nd, newlines, locals);
    break;

  case NODE_POSTEXE:            // END { ... }
    // Nothing to do here... we are in an iter block
    break;

  // Nodes we found but have yet to decypher
  // I think these are all runtime only... not positive but...
  case NODE_MEMO:               // enum.c zip
  case NODE_CFUNC:
  case NODE_CREF:
  case NODE_IFUNC:
  // #defines:
  // case NODE_LMASK:
  // case NODE_LSHIFT:
  default:
    rb_warn("Unhandled node #%d type '%s'", nd_type(node), node_type_string[nd_type(node)]);
    if (RNODE(node)->u1.node != NULL) rb_warning("unhandled u1 value");
    if (RNODE(node)->u2.node != NULL) rb_warning("unhandled u2 value");
    if (RNODE(node)->u3.node != NULL) rb_warning("unhandled u3 value");
    if (RTEST(ruby_debug)) fprintf(stderr, "u1 = %p u2 = %p u3 = %p\n", node->nd_1st, node->nd_2nd, node->nd_3rd);
    rb_ary_push(current, INT2FIX(-99));
    rb_ary_push(current, INT2FIX(nd_type(node)));
    break;
  }

 //  finish:
  if (contnode) {
      node = contnode;
      contnode = NULL;
      current = ary;
      ary = old_ary;
      old_ary = Qnil;
      goto again_no_block;
  }
}
^ # end of add_to_parse_tree block

    builder.c %q{
static VALUE parse_tree_for_meth(VALUE klass, VALUE method, VALUE newlines) {
  NODE *node = NULL;
  ID id;
  VALUE result = rb_ary_new();

  (void) self; // quell warnings
  (void) argc; // quell warnings

  id = rb_to_id(method);
  if (st_lookup(RCLASS(klass)->m_tbl, id, (st_data_t *) &node)) {
    rb_ary_push(result, ID2SYM(rb_intern("defn")));
    rb_ary_push(result, ID2SYM(id));
    add_to_parse_tree(result, node->nd_body, newlines, NULL);
  } else {
    rb_ary_push(result, Qnil);
  }

  return result;
}
}
  end # inline call
end # ParseTree class
