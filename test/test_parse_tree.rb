#!/usr/local/bin/ruby -w

dir = File.expand_path "~/.ruby_inline"
if test ?d, dir then
  require 'fileutils'
  puts "nuking #{dir}"
  FileUtils.rm_r dir
end

require 'test/unit'
require 'parse_tree'
require 'test/something'

class SomethingWithInitialize
  def initialize; end # this method is private
  protected
  def protected_meth; end
end

class TestParseTree < Test::Unit::TestCase

  def test_class_initialize
    expected = [[:class, :SomethingWithInitialize, :Object,
      [:defn, :initialize, [:scope, [:block, [:args], [:nil]]]],
      [:defn, :protected_meth, [:scope, [:block, [:args], [:nil]]]],
    ]]
    tree = @thing.parse_tree SomethingWithInitialize
    assert_equal expected, tree
  end

  def test_parse_tree_for_string
    actual   = @thing.parse_tree_for_string '1 + nil', '(string)', 1, false
    expected = [[:call, [:lit, 1], :+, [:array, [:nil]]]]

    assert_equal expected, actual
  end

  def test_parse_tree_for_string_with_newlines
    actual   = @thing.parse_tree_for_string "1 +\n nil", 'test.rb', 5, true
    expected = [[:newline, 6, "test.rb"],
                [:call, [:lit, 1], :+, [:array, [:nil]]]]

    assert_equal expected, actual
  end

  def test_parse_tree_for_str
    actual   = @thing.parse_tree_for_str '1 + nil', '(string)', 1, false
    expected = [[:call, [:lit, 1], :+, [:array, [:nil]]]]

    assert_equal expected, actual
  end

  # TODO: need a test of interpolated strings

  @@self_classmethod = [:defn, :self_classmethod,
                        [:scope,
                         [:block,
                          [:args],
                          [:call, [:lit, 1], :+, [:array, [:lit, 1]]]]]]

  @@self_bmethod_maker = [:defn,
                          :self_bmethod_maker,
                          [:scope,
                           [:block,
                            [:args],
                            [:iter,
                             [:fcall, :define_method,
                              [:array, [:lit, :bmethod_added]]],
                             [:dasgn_curr, :x],
                             [:call, [:dvar, :x], :+, [:array, [:lit, 1]]]]]]]

  @@self_dmethod_maker = [:defn,
                          :self_dmethod_maker,
                          [:scope,
                           [:block,
                            [:args],
                            [:fcall,
                             :define_method,
                             [:array,
                              [:lit, :dmethod_added],
                              [:call, [:self], :method,
                               [:array, [:lit, :bmethod_maker]]]]]]]]

  @@missing = [nil]
  @@empty = [:defn, :empty,
    [:scope,
      [:block,
        [:args],
        [:nil]]]]
  @@stupid = [:defn, :stupid,
    [:scope,
      [:block,
        [:args],
        [:return, [:nil]]]]]
  @@simple = [:defn, :simple,
    [:scope,
      [:block,
        [:args, :arg1],
        [:fcall, :print,
          [:array, [:lvar, :arg1]]],
        [:fcall, :puts,
          [:array,
            [:call,
              [:call,
                [:lit, 4],
                :+,
                [:array, [:lit, 2]]],
             :to_s]]]]]]
  @@global = [:defn, :global,
    [:scope,
      [:block,
        [:args],
        [:call,
          [:gvar, :$stderr],
          :fputs,
          [:array, [:str, "blah"]]]]]]
  @@lasgn_call = [:defn, :lasgn_call,
    [:scope,
      [:block,
        [:args],
        [:lasgn, :c,
          [:call,
            [:lit, 2],
            :+,
            [:array, [:lit, 3]]]]]]]
  @@conditional1 = [:defn, :conditional1,
    [:scope,
      [:block,
        [:args, :arg1],
        [:if,
          [:call,
            [:lvar, :arg1],
            :==,
            [:array, [:lit, 0]]],
          [:return,
            [:lit, 1]], nil]]]]
  @@conditional2 = [:defn, :conditional2,
    [:scope,
      [:block,
        [:args, :arg1],
        [:if,
          [:call,
            [:lvar, :arg1],
            :==,
            [:array, [:lit, 0]]], nil,
          [:return,
            [:lit, 2]]]]]]
  @@conditional3 = [:defn, :conditional3,
    [:scope,
      [:block,
        [:args, :arg1],
        [:if,
          [:call,
            [:lvar, :arg1],
            :==,
            [:array, [:lit, 0]]],
          [:return,
            [:lit, 3]],
          [:return,
            [:lit, 4]]]]]]
  @@conditional4 = [:defn, :conditional4,
    [:scope,
      [:block,
        [:args, :arg1],
        [:if,
          [:call,
            [:lvar, :arg1],
            :==,
            [:array, [:lit, 0]]],
          [:return, [:lit, 2]],
          [:if,
            [:call,
              [:lvar, :arg1],
              :<,
              [:array, [:lit, 0]]],
            [:return, [:lit, 3]],
            [:return, [:lit, 4]]]]]]]
  @@iteration_body = [:scope,
                   [:block,
                    [:args],
                    [:lasgn, :array,
                     [:array, [:lit, 1], [:lit, 2], [:lit, 3]]],
                    [:iter,
                     [:call,
                      [:lvar, :array], :each],
                     [:dasgn_curr, :x],
                     [:block,
                      [:dasgn_curr, :y],
                      [:dasgn_curr, :y, [:call, [:dvar, :x], :to_s]],
                      [:fcall, :puts, [:array, [:dvar, :y]]]]]]]

  @@iteration1 = [:defn, :iteration1, @@iteration_body]
  @@iteration2 = [:defn, :iteration2, @@iteration_body]
  @@iteration3 = [:defn, :iteration3,
    [:scope,
      [:block,
        [:args],
        [:lasgn, :array1,
          [:array, [:lit, 1], [:lit, 2], [:lit, 3]]],
        [:lasgn, :array2,
          [:array, [:lit, 4], [:lit, 5], [:lit, 6], [:lit, 7]]],
        [:iter,
          [:call,
            [:lvar, :array1], :each],
          [:dasgn_curr, :x],
          [:iter,
            [:call,
              [:lvar, :array2], :each],
            [:dasgn_curr, :y],
            [:block,
              [:fcall, :puts,
                [:array, [:call, [:dvar, :x], :to_s]]],
              [:fcall, :puts,
                [:array, [:call, [:dvar, :y], :to_s]]]]]]]]]
  @@iteration4 = [:defn,
 :iteration4,
 [:scope,
  [:block,
   [:args],
   [:iter,
    [:call, [:lit, 1], :upto, [:array, [:lit, 3]]],
    [:dasgn_curr, :n],
    [:fcall, :puts, [:array, [:call, [:dvar, :n], :to_s]]]]]]]
  @@iteration5 = [:defn,
 :iteration5,
 [:scope,
      [:block,
   [:args],
   [:iter,
    [:call, [:lit, 3], :downto, [:array, [:lit, 1]]],
    [:dasgn_curr, :n],
    [:fcall, :puts, [:array, [:call, [:dvar, :n], :to_s]]]]]]]
  @@iteration6 = [:defn,
 :iteration6,
 [:scope,
      [:block,
   [:args],
   [:iter,
    [:call, [:lit, 3], :downto, [:array, [:lit, 1]]],
    nil,
    [:fcall, :puts, [:array, [:str, "hello"]]]]]]]
  @@opt_args = [:defn, :opt_args,
    [:scope,
      [:block,
        [:args, :arg1, :arg2, :"*args", [:block, [:lasgn, :arg2, [:lit, 42]]]],
        [:lasgn, :arg3,
          [:call,
            [:call,
              [:lvar, :arg1],
              :*,
              [:array, [:lvar, :arg2]]],
            :*,
            [:array, [:lit, 7]]]],
        [:fcall, :puts, [:array, [:call, [:lvar, :arg3], :to_s]]],
        [:return,
          [:str, "foo"]]]]]
  @@multi_args = [:defn, :multi_args,
    [:scope,
      [:block,
        [:args, :arg1, :arg2],
        [:lasgn, :arg3,
          [:call,
            [:call,
              [:lvar, :arg1],
              :*,
              [:array, [:lvar, :arg2]]],
            :*,
            [:array, [:lit, 7]]]],
        [:fcall, :puts, [:array, [:call, [:lvar, :arg3], :to_s]]],
        [:return,
          [:str, "foo"]]]]]
  @@bools = [:defn, :bools,
    [:scope,
      [:block,
        [:args, :arg1],
        [:if,
          [:call,
            [:lvar, :arg1], :nil?],
          [:return,
            [:false]],
          [:return,
            [:true]]]]]]
  @@case_stmt = [:defn, :case_stmt,
    [:scope,
      [:block,
        [:args],
        [:lasgn, :var, [:lit, 2]],
        [:lasgn, :result, [:str, ""]],
        [:case,
          [:lvar, :var],
          [:when,
            [:array, [:lit, 1]],
            [:block,
              [:fcall, :puts, [:array, [:str, "something"]]],
              [:lasgn, :result, [:str, "red"]]]],
          [:when,
            [:array, [:lit, 2], [:lit, 3]],
            [:lasgn, :result, [:str, "yellow"]]],
          [:when, [:array, [:lit, 4]], nil],
          [:lasgn, :result, [:str, "green"]]],
        [:case,
          [:lvar, :result],
          [:when, [:array, [:str, "red"]], [:lasgn, :var, [:lit, 1]]],
          [:when, [:array, [:str, "yellow"]], [:lasgn, :var, [:lit, 2]]],
          [:when, [:array, [:str, "green"]], [:lasgn, :var, [:lit, 3]]],
          nil],
        [:return, [:lvar, :result]]]]]
  @@eric_is_stubborn = [:defn,
    :eric_is_stubborn,
    [:scope,
      [:block,
        [:args],
        [:lasgn, :var, [:lit, 42]],
        [:lasgn, :var2, [:call, [:lvar, :var], :to_s]],
        [:call, [:gvar, :$stderr], :fputs, [:array, [:lvar, :var2]]],
        [:return, [:lvar, :var2]]]]]
  @@interpolated = [:defn,
    :interpolated,
    [:scope,
      [:block,
        [:args],
        [:lasgn, :var, [:lit, 14]],
        [:lasgn, :var2, [:dstr, "var is ", [:lvar, :var], [:str, ". So there."]]]]]]
  @@unknown_args = [:defn, :unknown_args,
    [:scope,
      [:block,
        [:args, :arg1, :arg2],
        [:return, [:lvar, :arg1]]]]]
  @@bbegin = [:defn, :bbegin,
    [:scope,
      [:block,
        [:args],
        [:begin,
          [:ensure,
            [:rescue,
              [:lit, 1],
              [:resbody,
                [:array, [:const, :SyntaxError]],
                [:block, [:lasgn, :e1, [:gvar, :$!]], [:lit, 2]],
                [:resbody,
                  [:array, [:const, :Exception]],
                  [:block, [:lasgn, :e2, [:gvar, :$!]], [:lit, 3]]]],
              [:lit, 4]],
            [:lit, 5]]]]]]
  @@bbegin_no_exception = [:defn, :bbegin_no_exception,
    [:scope,
      [:block,
        [:args],
        [:begin,
          [:rescue,
            [:lit, 5],
            [:resbody, nil, [:lit, 6]]]]]]]
  @@op_asgn = [:defn, :op_asgn,
               [:scope,
                [:block,
                 [:args],
                 [:lasgn, :a, [:lit, 0]],
                 [:op_asgn_or, [:lvar, :a], [:lasgn, :a, [:lit, 1]]],
                 [:op_asgn_and, [:lvar, :a], [:lasgn, :a, [:lit, 2]]],

                 [:lasgn, :b, [:zarray]],

                 [:op_asgn1, [:lvar, :b], [:array, [:lit, 1]], :"||", [:lit, 10]],
       [:op_asgn1, [:lvar, :b], [:array, [:lit, 2]], :"&&", [:lit, 11]],
       [:op_asgn1, [:lvar, :b], [:array, [:lit, 3]], :+, [:lit, 12]],

       [:lasgn, :s, [:call, [:const, :Struct], :new, [:array, [:lit, :var]]]],
       [:lasgn, :c, [:call, [:lvar, :s], :new, [:array, [:nil]]]],

       [:op_asgn2, [:lvar, :c], :var=, :"||", [:lit, 20]],
       [:op_asgn2, [:lvar, :c], :var=, :"&&", [:lit, 21]],
       [:op_asgn2, [:lvar, :c], :var=, :+, [:lit, 22]],

       [:op_asgn2, [:call, [:call, [:lvar, :c], :d], :e], :f=, :"||", [:lit, 42]],

       [:return, [:lvar, :a]]]]]
  @@determine_args = [:defn, :determine_args,
    [:scope,
      [:block,
        [:args],
          [:call,
            [:lit, 5],
            :==,
            [:array,
              [:fcall,
                :unknown_args,
                [:array, [:lit, 4], [:str, "known"]]]]]]]]

  @@bmethod_added = [:defn,
    :bmethod_added,
    [:bmethod,
      [:dasgn_curr, :x],
      [:call, [:dvar, :x], :+, [:array, [:lit, 1]]]]]
  
  @@dmethod_added = [:defn,
 :dmethod_added,
 [:dmethod,
  :bmethod_maker,
  [:scope,
   [:block,
    [:args],
    [:iter,
     [:fcall, :define_method, [:array, [:lit, :bmethod_added]]],
     [:dasgn_curr, :x],
     [:call, [:dvar, :x], :+, [:array, [:lit, 1]]]]]]]] if RUBY_VERSION < "1.9"

  @@attrasgn = [:defn,
    :attrasgn,
    [:scope,
      [:block,
        [:args],
        [:attrasgn, [:lit, 42], :method=, [:array, [:vcall, :y]]],
        [:attrasgn, 
          [:self],
          :type=, 
          [:array, [:call, [:vcall, :other], :type]]]]]]
  
  @@whiles = [:defn,
    :whiles,
    [:scope,
      [:block,
        [:args],
        [:while, [:false], [:fcall, :puts, [:array, [:str, "false"]]], true],
        [:while, [:false], [:fcall, :puts, [:array, [:str, "true"]]], false]]]]
  @@xstr = [:defn,
    :xstr,
    [:scope,
      [:block,
        [:args],
        [:xstr, 'touch 5']]]] 
  @@dxstr = [:defn,
    :dxstr,
    [:scope,
      [:block,
        [:args],
        [:dxstr, 'touch ', [:lit, 5]]]]] 

  @@__all = [:class, :Something, :Object]
  
  def setup
    @thing = ParseTree.new(false)
  end

  methods = Something.instance_methods(false)

  methods.sort.each do |meth|
    if class_variables.include?("@@#{meth}") then
      @@__all << eval("@@#{meth}")
      eval "def test_#{meth}; assert_equal @@#{meth}, @thing.parse_tree_for_method(Something, :#{meth}); end"
    else
      eval "def test_#{meth}; flunk \"You haven't added @@#{meth} yet\"; end"
    end
  end

  methods = Something.singleton_methods

# TODO: cleanup
  methods.sort.each do |meth|
    if class_variables.include?("@@self_#{meth}") then
      @@__all << eval("@@self_#{meth}")
      eval "def test_self_#{meth}; assert_equal @@self_#{meth}, @thing.parse_tree_for_method(Something, :#{meth}, true); end"
    else
      eval "def test_self_#{meth}; flunk \"You haven't added @@self_#{meth} yet\"; end"
    end
  end

  def test_missing
    assert_equal(@@missing,
		 @thing.parse_tree_for_method(Something, :missing),
		 "Must return -3 for missing methods")
  end

  def test_class
    assert_equal([@@__all],
		 @thing.parse_tree(Something),
		 "Must return a lot of shit")
  end
end

