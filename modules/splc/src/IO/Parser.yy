%skeleton "lalr1.cc"
%require  "3.8.2"
%define parse.trace // This is required for runtime traces. For example, symbol_name.
%define parse.assert

%code requires{
    // Code section there will be placed directly inside `IO/Parser.hh`.
    #include "Core/Utils/LocationWrapper.hh"
    #include "Core/Base.hh"
    namespace splc {
    
    class AST;
    using PtrAST = Ptr<AST>;
    class TranslationManager;

    namespace IO {
        class Driver;
        class Scanner;
        class Parser;
    } // namespace splc::IO

    } // namespace splc

    // TODO: finish all error recovery
}

%parse-param { TranslationManager  &transMgr }
%parse-param { Driver              &driver  }
%parse-param { Scanner             &scanner  }

%code{
    #include <iostream>
    #include <cstdlib>
    #include <fstream>
    
    // include for all driver functions
    #include "Core/splc.hh"

    #include "IO/Driver.hh"

    #include "AST/AST.hh"
    #include "Translation/TranslationManager.hh"

    using SymbolType = splc::ASTSymbolType;

    #undef yylex
    #define yylex scanner.yylex
}

//===----------------------------------------------------------------------===//
//                               API Settings
//===----------------------------------------------------------------------===//
%define api.namespace {splc::IO}
%define api.parser.class {Parser}
// %define api.header.include { "IO/Parser.hh" }
// %define api.location.file "../../include/Core/Utils/location.hh"
%define api.location.type { splc::Location }

%define api.symbol.prefix {Sym} // The empty prefix is generally invalid, but there is namespace in C++.
%define api.value.type { splc::PtrAST }
%locations


//===----------------------------------------------------------------------===//
//                              Token Definitions 
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//===-Storage Qualifiers
%token KwdAuto KwdExtern KwdRegister KwdStatic KwdTypedef

//===----------------------------------------------------------------------===//
//===-Type Qualifiers
%token KwdConst KwdRestrict KwdVolatile

//===----------------------------------------------------------------------===//
//===-Function Specifiers
%token KwdInline

//===----------------------------------------------------------------------===//
//===-Primitive Type Specifiers
%token VoidTy IntTy SignedTy UnsignedTy LongTy FloatTy DoubleTy CharTy
%token KwdEnum 

//===----------------------------------------------------------------------===//
//===-Aggregate Type Specifier
%token KwdStruct KwdUnion

//===----------------------------------------------------------------------===//
//===-Keywords
// Flow Controls
%token KwdIf KwdElse KwdSwitch
%token KwdWhile KwdFor KwdDo
// Labels
%token KwdDefault KwdCase 
// Jumps
%token KwdGoto KwdContinue KwdBreak KwdReturn

//===----------------------------------------------------------------------===//
//===-IDs
%token ID TypedefID 

//===----------------------------------------------------------------------===//
//===-Operators
// Assignments
%token OpAssign 
%token OpMulAssign OpDivAssign OpModAssign OpPlusAssign OpMinusAssign 
%token OpLShiftAssign OpRShiftAssign OpBAndAssign OpBXorAssign OpBOrAssign

// Conditional
%token OpAnd OpOr OpNot
%token OpLT OpLE OpGT OpGE OpNE OpEQ 
%token OpQMark OpColon

// Arithmetics
%token OpLShift OpRShift
%token OpBAnd OpBOr OpBNot OpBXor

%token OpDPlus OpDMinus OpPlus OpMinus OpAstrk OpDiv OpMod

// Builtin
%token OpDot OpRArrow
%token OpSizeOf
%token OpLSB OpRSB 

// Misc
%token OpComma OpEllipsis

//===----------------------------------------------------------------------===//
//===-Punctuators
%token PSemi
%token PLC PRC
%token PLP PRP

//===-Literals
%token UIntLiteral SIntLiteral FloatLiteral CharLiteral StrUnit

//===----------------------------------------------------------------------===//
//                           Additional Tokens
//===----------------------------------------------------------------------===//
%token SubscriptExpr CallExpr AccessExpr 
%token ExplicitCastExpr
%token AddrOfExpr DerefExpr
%token SizeOfExpr

//===----------------------------------------------------------------------===//
//                         Precedence Specification
//===----------------------------------------------------------------------===//
%precedence KwdThen
%precedence KwdElse

%left OpComma
%right OpAssign OpMulAssign OpDivAssign OpModAssign OpPlusAssign OpMinusAssign OpLShiftAssign OpRShiftAssign OpBAndAssign OpBXorAssign OpBOrAssign
%right OpQMark OpColon
%left OpOr
%left OpAnd
%left OpBOr
%left OpBXor
%left OpBAnd
%left OpLT OpLE OpGT OpGE OpNE OpEQ 
%left OpPlus OpMinus
%left OpAstrk OpDiv OpMod
%right OpUnaryPrec
%right OpNot OpBNot OpDPlus OpDMinus OpSizeOf
%left PLParen PRParen PLSBracket PRSBracket OpDot

//===----------------------------------------------------------------------===//
//                              Test Specification
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//                           Production Definitions
//===----------------------------------------------------------------------===//
%%
/* Entire translation unit */
ParseRoot: 
    { transMgr.pushASTContext(); } 
    TransUnit {
        transMgr.setRootNode($TransUnit);
        SPLC_LOG_DEBUG(&@TransUnit, true) << "completed parsing";

        transMgr.popASTContext(); 
    }
    ;

TransUnit: 
      ExternDeclList { $$ = transMgr.makeAST<AST>(SymbolType::TransUnit, @$, $1); }
    | { $$ = transMgr.makeAST<AST>(SymbolType::TransUnit, @$); }
    ;

/* External definition list: Recursive definition */
ExternDeclList: 
      ExternDecl { $$ = transMgr.makeAST<AST>(SymbolType::ExternDeclList, @1, $1); }
    | ExternDeclList ExternDecl { $1->addChild($2); $$ = $1; }
    ;

/* External definition list: A single unit of one of {}. */
ExternDecl: 
      PSemi { $$ = transMgr.makeAST<AST>(SymbolType::ExternDecl, @$); }
    | Decl { $$ = transMgr.makeAST<AST>(SymbolType::ExternDecl, @$, $1); }
    | FuncDef { $$ = transMgr.makeAST<AST>(SymbolType::ExternDecl, @$, $1); }
    ;

DeclSpec:
      StorageSpec { $$ = transMgr.makeAST<AST>(SymbolType::DeclSpec, @$, $1); }
    | TypeSpec { $$ = transMgr.makeAST<AST>(SymbolType::DeclSpec, @$, $1); }
    | TypeQual { $$ = transMgr.makeAST<AST>(SymbolType::DeclSpec, @$, $1); }
    | FuncSpec { $$ = transMgr.makeAST<AST>(SymbolType::DeclSpec, @$, $1); }
    | DeclSpec TypeSpec { $1->addChild($2); $$ = $1; }
    | DeclSpec StorageSpec { $1->addChild($2); $$ = $1; }
    | DeclSpec TypeQual { $1->addChild($2); $$ = $1; }
    | DeclSpec FuncSpec { $1->addChild($2); $$ = $1; }
    ;

StorageSpec:
      KwdAuto { $$ = transMgr.makeAST<AST>(SymbolType::StorageSpec, @$, $1); }
    | KwdExtern { $$ = transMgr.makeAST<AST>(SymbolType::StorageSpec, @$, $1); }
    | KwdRegister { $$ = transMgr.makeAST<AST>(SymbolType::StorageSpec, @$, $1); }
    | KwdStatic { $$ = transMgr.makeAST<AST>(SymbolType::StorageSpec, @$, $1); }
    | KwdTypedef { $$ = transMgr.makeAST<AST>(SymbolType::StorageSpec, @$, $1); }
    ;

SpecQualList:
      TypeSpec { $$ = transMgr.makeAST<AST>(SymbolType::SpecQualList, @$, $1); }
    | TypeQual { $$ = transMgr.makeAST<AST>(SymbolType::SpecQualList, @$, $1); }
    | SpecQualList TypeSpec { $1->addChild($2); $$ = $1; }
    | SpecQualList TypeQual { $1->addChild($2); $$ = $1; }
    ;

TypeSpec: 
      BuiltinTypeSpec { $$ = transMgr.makeAST<AST>(SymbolType::TypeSpec, @$, $1); }
    /* | identifier {} */
    | StructOrUnionSpec { $$ = transMgr.makeAST<AST>(SymbolType::TypeSpec, @$, $1); }
    | EnumSpec { $$ = transMgr.makeAST<AST>(SymbolType::TypeSpec, @$, $1); }
    | TypedefID { $$ = transMgr.makeAST<AST>(SymbolType::TypeSpec, @$, $1); }
    ;

FuncSpec:
      KwdInline { $$ = transMgr.makeAST<AST>(SymbolType::FuncSpec, @$, $1); }
    ;

TypeQual:
      KwdConst { $$ = transMgr.makeAST<AST>(SymbolType::TypeQual, @$, $1); }
    | KwdRestrict { $$ = transMgr.makeAST<AST>(SymbolType::TypeQual, @$, $1); }
    | KwdVolatile { $$ = transMgr.makeAST<AST>(SymbolType::TypeQual, @$, $1); }
    ;

TypeName:
      SpecQualList { $$ = transMgr.makeAST<AST>(SymbolType::TypeName, @$, $1); }
    | SpecQualList AbsDecltr { $$ = transMgr.makeAST<AST>(SymbolType::TypeQual, @$, $1, $2); }
    ;

BuiltinTypeSpec:
      VoidTy
    | IntTy
    | FloatTy
    | DoubleTy
    | CharTy
    | SignedTy
    | UnsignedTy
    | LongTy
    ;

AbsDecltr:
      Ptr { $$ = transMgr.makeAST<AST>(SymbolType::AbsDecltr, @$, $1); }
    | Ptr DirAbsDecltr { $$ = transMgr.makeAST<AST>(SymbolType::AbsDecltr, @$, $1, $2); }
    ;

DirAbsDecltr:
      PLP AbsDecltr PRP { $$ = transMgr.makeAST<AST>(SymbolType::DirAbsDecltr, @$, $1); }
    | DirAbsDecltr OpLSB AssignExpr OpRSB { $$ = transMgr.makeAST<AST>(SymbolType::DirAbsDecltr, @$, $1, $2, $3, $4); }
    | DirAbsDecltr OpLSB OpRSB { $$ = transMgr.makeAST<AST>(SymbolType::DirAbsDecltr, @$, $1, $2, $3); }
    | DirAbsDecltr OpLSB error { SPLC_LOG_ERROR(&@3, true) << "Expect ']' here"; $$ = transMgr.makeAST<AST>(SymbolType::DirAbsDecltr, @$, $1); yyerrok; }
    | DirAbsDecltr OpRSB { SPLC_LOG_ERROR(&@2, true) << "Expect '[' here"; $$ = transMgr.makeAST<AST>(SymbolType::DirAbsDecltr, @$, $1); yyerrok; } 
    ;

/* Specify a structure */
StructOrUnionSpec: 
      StructOrUnion IDWrapper { $$ = transMgr.makeAST<AST>(SymbolType::StructOrUnionSpec, @$, $1, $2); }
    | StructOrUnion StructDeclBody { $$ = transMgr.makeAST<AST>(SymbolType::StructOrUnionSpec, @$, $1, $2); }
    | StructOrUnion IDWrapper StructDeclBody { $$ = transMgr.makeAST<AST>(SymbolType::StructOrUnionSpec, @$, $1, $2, $3); }
    ;

StructOrUnion:
      KwdStruct
    | KwdUnion
    ;

StructDeclBody:
      PLC PRC { $$ = transMgr.makeAST<AST>(SymbolType::StructDeclBody, @$); }
    | PLC StructDeclList PRC { $$ = transMgr.makeAST<AST>(SymbolType::StructDeclBody, @$, $1); }

    | PLC error { SPLC_LOG_ERROR(&@1, true) << "expect token '}'"; $$ = transMgr.makeAST<AST>(SymbolType::StructDeclBody, @$); yyerrok; }
    | PLC StructDeclList error { SPLC_LOG_ERROR(&@3, true) << "expect token '}'"; $$ = transMgr.makeAST<AST>(SymbolType::StructDeclBody, @$, $2); yyerrok; }
    ;

StructDeclList:
      StructDecl { $$ = transMgr.makeAST<AST>(SymbolType::StructDeclBody, @$, $1); }
    | StructDeclList StructDecl { $1->addChild($2); $$ = $1; }
    ;

StructDecl:
      SpecQualList PSemi { $$ = transMgr.makeAST<AST>(SymbolType::StructDecl, @$, $1); }
    | SpecQualList StructDecltrList PSemi { $$ = transMgr.makeAST<AST>(SymbolType::StructDecl, @$, $1, $2); }

    | SpecQualList error {}
    | SpecQualList StructDecltrList error {}
    ;

StructDecltrList:
      StructDecltr { $$ = transMgr.makeAST<AST>(SymbolType::StructDecltrList, @$, $1); }
    | StructDecltrList OpComma StructDecltr { $1->addChild($3); $$ = $1; }

    | StructDecltrList OpComma error {}
    ;

StructDecltr:
      Decltr { $$ = transMgr.makeAST<AST>(SymbolType::StructDecltr, @$, $1); }
    | OpColon ConstExpr { $$ = transMgr.makeAST<AST>(SymbolType::StructDecltr, @$, $1, $2); }
    | Decltr OpColon ConstExpr { $$ = transMgr.makeAST<AST>(SymbolType::StructDecltr, @$, $1, $2, $3); }

    | OpColon error {}
    | Decltr OpColon error {}
    ;

EnumSpec:
      KwdEnum IDWrapper { $$ = transMgr.makeAST<AST>(SymbolType::EnumSpec, @$, $1, $2); }
    | KwdEnum EnumBody { $$ = transMgr.makeAST<AST>(SymbolType::EnumSpec, @$, $1, $2); }
    | KwdEnum IDWrapper EnumBody { $$ = transMgr.makeAST<AST>(SymbolType::EnumSpec, @$, $1, $2, $3); }
    
    | KwdEnum error {}
    ;

EnumBody:
      PLC PRC { $$ = transMgr.makeAST<AST>(SymbolType::EnumBody, @$); }
    | PLC EnumeratorList PRC { $$ = transMgr.makeAST<AST>(SymbolType::EnumBody, @$, $2); }
    | PLC EnumeratorList OpComma PRC { $$ = transMgr.makeAST<AST>(SymbolType::EnumBody, @$, $2); }

    | PLC error {}
    | PLC EnumeratorList error {}
    ;

EnumeratorList:
      Enumerator { $$ = transMgr.makeAST<AST>(SymbolType::EnumeratorList, @$, $1); }
    | EnumeratorList OpComma Enumerator { $1->addChild($3); $$ = $1; }

    | OpComma Enumerator {}
    ;

Enumerator:
      EnumConst { $$ = transMgr.makeAST<AST>(SymbolType::Enumerator, @$, $1); }
    | EnumConst OpAssign ConstExpr { $$ = transMgr.makeAST<AST>(SymbolType::Enumerator, @$, $1, $2, $3); }

    | EnumConst OpAssign error {}
    ;

EnumConst:
      IDWrapper { $$ = transMgr.makeAST<AST>(SymbolType::EnumConst, @$, $1); }
    ;

/* Single variable declaration */
Decltr: 
      Ptr DirDecltr { $$ = transMgr.makeAST<AST>(SymbolType::Decltr, @$, $1, $2); }
    | DirDecltr { $$ = transMgr.makeAST<AST>(SymbolType::Decltr, @$, $1); }
    ;

DirDecltr:
      IDWrapper { $$ = transMgr.makeAST<AST>(SymbolType::DirDecltr, @$, $1); }
    | PLP Decltr PRP { $$ = transMgr.makeAST<AST>(SymbolType::DirDecltr, @$, $2); }
    | DirDecltr OpLSB AssignExpr OpRSB { $$ = transMgr.makeAST<AST>(SymbolType::DirDecltr, @$, $1, $2, $3, $4); }
    | DirDecltr OpLSB OpRSB { $$ = transMgr.makeAST<AST>(SymbolType::DirDecltr, @$, $1, $2, $3); }

    | DirDecltr OpLSB AssignExpr error {} 
    /* | direct-declarator error {}  */
    | DirDecltr OpRSB {} 
    ;

Ptr:
      OpAstrk { $$ = transMgr.makeAST<AST>(SymbolType::Ptr, @$, $1); }
    | OpAstrk TypeQualList { $$ = transMgr.makeAST<AST>(SymbolType::Ptr, @$, $1, $2); }
    | OpAstrk Ptr { $$ = transMgr.makeAST<AST>(SymbolType::Ptr, @$, $1, $2); }
    | OpAstrk TypeQualList Ptr { $$ = transMgr.makeAST<AST>(SymbolType::Ptr, @$, $1, $2, $3); }
    ;

TypeQualList:
      TypeQual { $$ = transMgr.makeAST<AST>(SymbolType::TypeQualList, @$, $1); } 
    | TypeQualList TypeQual { $1->addChild($2); $$ = $1; }
    ;

/* Definition: List of definitions. Recursive definition. */
/* declaration-list: 
      declaration {}
    | declaration-list declaration {}
    ; */

/* Definition: Base */
Decl: 
      DirDecl PSemi { $$ = transMgr.makeAST<AST>(SymbolType::Decl, @$, $1); }

    | DirDecl error {}
    ;

DirDecl:
      DeclSpec { $$ = transMgr.makeAST<AST>(SymbolType::DirDecl, @$, $1); }
    | DeclSpec InitDecltrList { $$ = transMgr.makeAST<AST>(SymbolType::DirDecl, @$, $1, $2); }
    ;

/* Definition: Declaration of multiple variable.  */ 
InitDecltrList: 
      InitDecltr { $$ = transMgr.makeAST<AST>(SymbolType::InitDecltrList, @$, $1); }
    | InitDecltrList OpComma InitDecltr{ $1->addChild($3); $$ = $3; }

    | InitDecltrList OpComma {}
    | OpComma InitDecltr {}
    | OpComma {}
    ;

/* Definition: Single declaration unit. */
InitDecltr: 
      Decltr { $$ = transMgr.makeAST<AST>(SymbolType::InitDecltr, @$, $1); }
    | Decltr OpAssign Initializer { $$ = transMgr.makeAST<AST>(SymbolType::InitDecltr, @$, $1, $2, $3); }

    | Decltr OpAssign error {}
    ;

Initializer:
      AssignExpr { $$ = transMgr.makeAST<AST>(SymbolType::Initializer, @$, $1); }
    | PLC InitializerList PRC { $$ = transMgr.makeAST<AST>(SymbolType::Initializer, @$, $2); }
    | PLC InitializerList OpComma PRC { $$ = transMgr.makeAST<AST>(SymbolType::Initializer, @$, $2); }

    | PLC InitializerList error {}
    ;

InitializerList:
      Initializer { $$ = transMgr.makeAST<AST>(SymbolType::InitializerList, @$, $1); }
    | Designation Initializer { $$ = transMgr.makeAST<AST>(SymbolType::InitializerList, @$, $1, $2); }
    | InitializerList OpComma Designation Initializer { $1->addChildren($3, $4) ; $$ = $1; }
    | InitializerList OpComma Initializer { $1->addChild($3) ; $$ = $1; }

    | Designation error {}
    | InitializerList OpComma error {}
    ;

Designation:
      DesignatorList OpAssign { $$ = transMgr.makeAST<AST>(SymbolType::Designation, @$, $1, $2); }
    ;

DesignatorList:
      Designator { $$ = transMgr.makeAST<AST>(SymbolType::DesignatorList, @$, $1); }
    | DesignatorList Designator { $1->addChild($2) ; $$ = $1; }
    ;

Designator:
      OpLSB ConstExpr OpRSB { $$ = transMgr.makeAST<AST>(SymbolType::Designator, @$, $1, $2, $3); }
    | OpDot IDWrapper { $$ = transMgr.makeAST<AST>(SymbolType::Designator, @$, $1, $2); }

    | OpLSB ConstExpr error {}
    | OpDot error {}
    ;

FuncDef:
      DeclSpec FuncDecltr CompStmt { $$ = transMgr.makeAST<AST>(SymbolType::FuncDef, @$, $1, $2, $3); }
    | FuncDecltr CompStmt { SPLC_LOG_WARN(&@1, true) << "function is missing a specifier and will default to 'int'"; $$ = transMgr.makeAST<AST>(SymbolType::FuncDef, @$, $1, $2); } 
    | DeclSpec FuncDecltr PSemi { $$ = transMgr.makeAST<AST>(SymbolType::FuncDef, @$, $1, $2); }

    | DeclSpec FuncDecltr error {}
    ;

/* Function: Function name and body. */
FuncDecltr: 
      DirFuncDecltr { $$ = transMgr.makeAST<AST>(SymbolType::FuncDecltr, @$, $1); }
    | Ptr DirFuncDecltr { $$ = transMgr.makeAST<AST>(SymbolType::FuncDecltr, @$, $1, $2); }
    ;

DirFuncDecltr:
      DirDecltrForFunc PLP ParamTypeList PRP { $$ = transMgr.makeAST<AST>(SymbolType::DirFuncDecltr, @$, $1, $3); }
    /* | direct-declarator-for-function PLP PRP {} */

    /* | direct-declarator-for-function PLP error {} */
    | DirDecltrForFunc PLP ParamTypeList error {}
    /* | direct-declarator-for-function PLP error {} */

    | PLP ParamTypeList PRP {}
    /* | PLP PRP {} */
    ;

DirDecltrForFunc:
      IDWrapper {}
    ;

/* List of variables names */
ParamTypeList: 
      { $$ = transMgr.makeAST<AST>(SymbolType::ParamTypeList, @$); }
    | ParamList { $$ = transMgr.makeAST<AST>(SymbolType::ParamTypeList, @$, $1); }
    | ParamList OpComma OpEllipsis { $$ = transMgr.makeAST<AST>(SymbolType::ParamTypeList, @$, $1, $3); }
    ;

ParamList:
      ParamDecl { $$ = transMgr.makeAST<AST>(SymbolType::ParamList, @$, $1); }
    | ParamList OpComma ParamDecl { $1->addChild($3); $$ = $1; }

    | ParamList OpComma error {}
    | OpComma {}
    ;

/* Parameter declaration */ 
ParamDecl: 
      DeclSpec Decltr { $$ = transMgr.makeAST<AST>(SymbolType::ParamDecl, @$, $1, $2); }
    | DeclSpec AbsDecltr { $$ = transMgr.makeAST<AST>(SymbolType::ParamDecl, @$, $1, $2); }
    | DeclSpec { $$ = transMgr.makeAST<AST>(SymbolType::ParamDecl, @$, $1); }

    /* | error {} */
    ;

/* Compound statement: A new scope. */
CompStmt: 
      /* PLC general-statement-list PRC */
      PLC GeneralStmtList PRC { $$ = transMgr.makeAST<AST>(SymbolType::CompStmt, @$, $2); }
    | PLC PRC { $$ = transMgr.makeAST<AST>(SymbolType::CompStmt, @$); }

    | PLC GeneralStmtList error {}
    | PLC error {}
    ;

/* wrapper for C99 standard for statements */
GeneralStmtList: 
      Stmt { $$ = transMgr.makeAST<AST>(SymbolType::GeneralStmtList, @$, $1); }
    | Decl { $$ = transMgr.makeAST<AST>(SymbolType::GeneralStmtList, @$, $1); }
    | GeneralStmtList Stmt { $1->addChild($2); $$ = $1; }
    | GeneralStmtList Decl { $1->addChild($2); $$ = $1; }
    ;

/* Statement: List of statements. Recursive definition. */
/* statement-list: 
      statement {}
    | statement-list statement {} 
    ; */

/* Statement: A single statement. */
Stmt: // TODO: use hierarchy
      PSemi { $$ = transMgr.makeAST<AST>(SymbolType::Stmt, @$); }
    | CompStmt { $$ = transMgr.makeAST<AST>(SymbolType::Stmt, @$, $1); }
    | ExprStmt { $$ = transMgr.makeAST<AST>(SymbolType::Stmt, @$, $1); }
    | SelStmt { $$ = transMgr.makeAST<AST>(SymbolType::Stmt, @$, $1); }
    | IterStmt { $$ = transMgr.makeAST<AST>(SymbolType::Stmt, @$, $1); }
    | LabeledStmt { $$ = transMgr.makeAST<AST>(SymbolType::Stmt, @$, $1); }
    | JumpStmt { $$ = transMgr.makeAST<AST>(SymbolType::Stmt, @$, $1); }

    /* | error PSemi {} */
    ;

ExprStmt:
      Expr PSemi { $$ = transMgr.makeAST<AST>(SymbolType::ExprStmt, @$, $1); }
    | Expr error {}
    ;

SelStmt:
      KwdIf PLP Expr PRP Stmt %prec KwdThen { $$ = transMgr.makeAST<AST>(SymbolType::SelStmt, @$, $1, $3, $5); }

    | KwdIf error PRP Stmt %prec KwdThen {}
    | KwdIf PLP PRP Stmt %prec KwdThen {}
    | KwdIf PLP Expr PRP error %prec KwdThen {}
    | KwdIf PLP PRP error %prec KwdThen {}
    
    | KwdIf PLP Expr PRP Stmt KwdElse Stmt %prec KwdElse { $$ = transMgr.makeAST<AST>(SymbolType::SelStmt, @$, $1, $3, $5, $6, $7); }

    | KwdIf error PRP Stmt KwdElse Stmt %prec KwdElse {}
    | KwdIf PLP Expr PRP Stmt KwdElse error %prec KwdElse {}
    | KwdIf PLP PRP Stmt KwdElse Stmt %prec KwdElse {}
    | KwdIf PLP PRP Stmt KwdElse error %prec KwdElse {}
    | KwdIf PLP Expr error %prec KwdElse {}
    | KwdElse Stmt {}

    | KwdSwitch PLP Expr PRP Stmt { $$ = transMgr.makeAST<AST>(SymbolType::SelStmt, @$, $KwdSwitch, $Expr, $Stmt); }
    /* | KwdSwitch PLP expression statement {} */
    | KwdSwitch error PRP Stmt {}
    ;

LabeledStmt:
      IDWrapper OpColon Stmt { $$ = transMgr.makeAST<AST>(SymbolType::LabeledStmt, @$, $1, $2, $3); }
    | KwdCase ConstExpr OpColon Stmt { $$ = transMgr.makeAST<AST>(SymbolType::LabeledStmt, @$, $1, $2, $3, $4); }
    | KwdDefault OpColon Stmt { $$ = transMgr.makeAST<AST>(SymbolType::LabeledStmt, @$, $1, $2, $3); }

    | OpColon Stmt {}
    ;

JumpStmt:
      KwdGoto IDWrapper PSemi { $$ = transMgr.makeAST<AST>(SymbolType::JumpStmt, @$, $1, $2); }
    | KwdContinue PSemi { $$ = transMgr.makeAST<AST>(SymbolType::JumpStmt, @$, $1); }
    | KwdBreak PSemi { $$ = transMgr.makeAST<AST>(SymbolType::JumpStmt, @$, $1); }
    | KwdReturn Expr PSemi { $$ = transMgr.makeAST<AST>(SymbolType::JumpStmt, @$, $1, $2); }
    | KwdReturn PSemi { $$ = transMgr.makeAST<AST>(SymbolType::JumpStmt, @$, $1); }

    | KwdReturn Expr error {}
    | KwdReturn error {}
    ;

IterStmt:
      KwdWhile PLP Expr PRP Stmt { $$ = transMgr.makeAST<AST>(SymbolType::IterStmt, @$, $KwdWhile, $Expr, $Stmt); }
    | KwdWhile error PRP Stmt {}
    | KwdWhile PLP Expr PRP error {}
    | KwdWhile PLP Expr error {}
    
    | KwdDo Stmt KwdWhile PLP Expr PRP PSemi { $$ = transMgr.makeAST<AST>(SymbolType::IterStmt, @$, $KwdDo, $Stmt, $KwdWhile, $Expr); }
    | KwdDo Stmt KwdWhile PLP error PSemi {}

    | KwdFor PLP ForLoopBody PRP Stmt { $$ = transMgr.makeAST<AST>(SymbolType::IterStmt, @$, $KwdFor, $ForLoopBody, $Stmt); }
    | KwdFor PLP ForLoopBody PRP error {}
    | KwdFor PLP ForLoopBody error {}
    ;

ForLoopBody: // TODO: add constant expressions 
      InitExpr PSemi Expr PSemi Expr { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2, $3, $4, $5); }

    | PSemi Expr PSemi Expr { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2, $3, $4); } 
    | InitExpr PSemi Expr PSemi { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2, $3, $4); }
    | InitExpr PSemi PSemi Expr { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2, $3, $4); }

    | PSemi Expr PSemi { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2, $3); }
    | PSemi PSemi Expr { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2, $3); }
    /* | definition PSemi {} */
    | InitExpr PSemi PSemi { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2, $3); }
    
    | PSemi PSemi { $$ = transMgr.makeAST<AST>(SymbolType::ForLoopBody, @$, $1, $2); }
    ;

ConstExpr: 
      CondExpr { $$ = transMgr.makeAST<AST>(SymbolType::ConstExpr, @$, $1); }
    ;

Constant:
      UIntLiteral { $$ = transMgr.makeAST<AST>(SymbolType::Constant, @$, $1); }
    | SIntLiteral { $$ = transMgr.makeAST<AST>(SymbolType::Constant, @$, $1); }
    | FloatLiteral { $$ = transMgr.makeAST<AST>(SymbolType::Constant, @$, $1); }
    | CharLiteral { $$ = transMgr.makeAST<AST>(SymbolType::Constant, @$, $1); }
    /* | StrUnit {} */
    ;

PrimaryExpr:
      IDWrapper { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1); }
    | Constant { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1); }
    | StringLiteral { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1); }
    | PLP Expr PRP { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $2); }

    | PLP Expr error {}
    /* | PLP expression {} */
    ;

PostfixExpr:
      PrimaryExpr
    | PostfixExpr OpLSB Expr OpRSB { $$ = transMgr.makeAST<AST>(SymbolType::SubscriptExpr, @$, $1, $2, $3, $4); }
    | PostfixExpr PLP ArgList PRP { $$ = transMgr.makeAST<AST>(SymbolType::CallExpr, @$, $1, $3); }
    /* | postfix-expression PLP PRP {} */
    | PostfixExpr MemberAcessOp IDWrapper { $$ = transMgr.makeAST<AST>(SymbolType::AccessExpr, @$, $1, $2, $3); }
    | PostfixExpr OpDPlus { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2); }
    | PostfixExpr OpDMinus { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2); }
    | PLP TypeName PRP PLC InitializerList PRC { $$ = transMgr.makeAST<AST>(SymbolType::ExplicitCastExpr, @$, $1, $2, $3, $5); }
    | PLP TypeName PRP PLC InitializerList OpComma PRC { $$ = transMgr.makeAST<AST>(SymbolType::ExplicitCastExpr, @$, $1, $2, $3, $5); }

    | PostfixExpr OpLSB Expr error {}
    | PostfixExpr PLP ArgList error {}
    | PostfixExpr MemberAcessOp {}
    | OpRArrow IDWrapper {}
    | PLP TypeName PRP PLC InitializerList error {}
    ;

MemberAcessOp:
      OpDot
    | OpRArrow
    ;

UnaryExpr:
      PostfixExpr
    | OpDPlus UnaryExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2); }
    | OpDMinus UnaryExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2); }
    | OpBAnd CastExpr %prec OpUnaryPrec { $$ = transMgr.makeAST<AST>(SymbolType::AddrOfExpr, @$, $1, $2); }
    | OpAstrk CastExpr %prec OpUnaryPrec { $$ = transMgr.makeAST<AST>(SymbolType::DerefExpr, @$, $1, $2); }
    | UnaryArithOp CastExpr %prec OpUnaryPrec { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2); }
    | OpSizeOf UnaryExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2); }
    | OpSizeOf PLP TypeName PRP { $$ = transMgr.makeAST<AST>(SymbolType::SizeOfExpr, @$, $1, $3); }

    | OpBAnd error {}
    | OpAstrk error {}
    | OpBNot error {}
    | OpNot error {}
    | OpDPlus error {}
    | OpDMinus error {}
    | OpSizeOf error {}
    /* | OpSizeOf PLP unary-expression PRP {} */
    ;

UnaryArithOp: /* Take the default behavior, that is, `$$ = $1` */
      OpPlus
    | OpMinus
    | OpBNot
    | OpNot
    ;


CastExpr:
      UnaryExpr
    | PLP TypeName PRP CastExpr { $$ = transMgr.makeAST<AST>(SymbolType::ExplicitCastExpr, @$, $1, $2); }

    | PLP TypeName PRP error {}
    | PLP TypeName error {}
    ;

MulExpr:
      CastExpr
    | MulExpr MulOp CastExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | MulExpr MulOp error {}
    | DivOp CastExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2); }
    ;
  
MulOp:
      OpAstrk
    | DivOp
    ;

DivOp:
      OpDiv
    | OpMod
    ;

AddExpr:
      MulExpr
    | AddExpr AddOp MulExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | AddExpr AddOp error {}
    ;

AddOp:
      OpPlus
    | OpMinus
    ;

ShiftExpr:
      AddExpr
    | ShiftExpr ShiftOp AddExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | ShiftExpr ShiftOp error {}
    | ShiftOp AddExpr {}
    ;
  
ShiftOp:
      OpLShift
    | OpRShift
    ;

RelExpr:
      ShiftExpr
    | RelExpr RelOp ShiftExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | RelExpr RelOp error {}
    | RelOp ShiftExpr {}
    ;

RelOp:
      OpLT
    | OpGT
    | OpLE
    | OpGE
    ;

EqualityExpr:
      RelExpr
    | EqualityExpr EqualityOp RelExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | EqualityExpr EqualityOp error {}
    | EqualityOp RelExpr {}
    ;

EqualityOp:
      OpEQ
    | OpNE
    ;

OpBAndExpr:
      EqualityExpr
    | OpBAndExpr OpBAnd EqualityExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | OpBAndExpr OpBAnd error {}
    ;

OpBXorExpr:
      OpBAndExpr
    | OpBXorExpr OpBXor OpBAndExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | OpBXorExpr OpBXor error {}
    | OpBXor OpBAndExpr {}
    ;

OpBOrExpr:
      OpBXorExpr
    | OpBOrExpr OpBOr OpBXorExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | OpBOrExpr OpBOr error {}
    | OpBOr OpBXorExpr {}
    ;

LogicalOpAndExpr:
      OpBOrExpr
    | LogicalOpAndExpr OpAnd OpBOrExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | LogicalOpAndExpr OpAnd error {}
    | OpAnd OpBOrExpr {}
    ;

LogicalOpOrExpr:
      LogicalOpAndExpr
    | LogicalOpOrExpr OpOr LogicalOpAndExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }

    | LogicalOpOrExpr OpOr error {}
    | OpOr LogicalOpAndExpr {}
    ;

CondExpr:
      LogicalOpOrExpr
    | LogicalOpOrExpr OpQMark Expr OpColon CondExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3, $4, $5); }

    | LogicalOpOrExpr OpQMark OpColon CondExpr {}
    | LogicalOpOrExpr OpQMark Expr OpColon {}
    | OpQMark error {}
    ;

AssignExpr:
      CondExpr
    
    | CondExpr AssignOp AssignExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $2, $3); }
    | CondExpr AssignOp error {}
    | AssignOp AssignExpr {}
    
    /* | unary-expression assignment-operator assignment-expression {} */
    /* | unary-expression assignment-operator error {} */
    /* | assignment-operator assignment-expression {} */
    ;
    
AssignOp: /* Use the default behavior to pass the value */
      OpAssign 
    | OpMulAssign
    | OpDivAssign
    | OpModAssign
    | OpPlusAssign
    | OpMinusAssign
    | OpLShiftAssign
    | OpRShiftAssign
    | OpBAndAssign
    | OpBXorAssign
    | OpBOrAssign
    ;

/* expressions */
Expr: 
      AssignExpr
    | Expr OpComma AssignExpr { $$ = transMgr.makeAST<AST>(SymbolType::Expr, @$, $1, $3); }

    | Expr OpComma error {}
    | OpComma AssignExpr {}
    ;
  
InitExpr:
      Expr { $$ = transMgr.makeAST<AST>(SymbolType::InitExpr, @$, $1); }
    | DirDecl { $$ = transMgr.makeAST<AST>(SymbolType::InitExpr, @$, $1); }
    ;

/* Argument: List of arguments */
ArgList: 
      { $$ = transMgr.makeAST<AST>(SymbolType::ArgList, @$); }
    | ArgList OpComma AssignExpr { $1->addChild($3); $$ = $1; }
    | AssignExpr { $$ = transMgr.makeAST<AST>(SymbolType::ArgList, @$, $1); }

    | ArgList OpComma error {}
    /* | error {} */
    ;

/* String intermediate expression. Allowing concatenation of strings. */
StringLiteral: 
      StrUnit { $$ = transMgr.makeAST<AST>(SymbolType::StringLiteral, @$, $1); }
    | StringLiteral StrUnit { $1->addChild($2); $$ = $1; }
    ;

IDWrapper:
      ID
    ;
%%


void splc::IO::Parser::error(const location_type &l, const std::string &err_message)
{
    SPLC_LOG_ERROR(&l, true) << err_message;
}