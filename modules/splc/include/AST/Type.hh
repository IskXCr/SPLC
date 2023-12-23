//===- splc/Type.hh - Classes for handling data types -----------*- C++ -*-===//
//
// Part of the SPLC project. Reference from the LLVM project under the Apache
// License v2.0 with LLVM exceptions.
// This file is a selected subset with manual modifications to satisfy
// requirements for course SUSTech CS323-Compiler.
//
//===----------------------------------------------------------------------===//
//
// This file contains the declaration of the Type class.  For more "Type"
// stuff, look in DerivedTypes.h.
//
//===----------------------------------------------------------------------===//

#ifndef __SPLC_AST_TYPE_HH__
#define __SPLC_AST_TYPE_HH__ 1

#include "Core/Base.hh"
#include "Core/Utils/Logging.hh"
#include "Core/splc.hh"
#include <iterator>
#include <random>
#include <type_traits>
#include <vector>

namespace splc {

class TypeContext;

class Type;
class PointerType;
class ArrayType;
class StructType;
class FunctionType;

template <class... Tys>
concept AreBaseOfType = (std::is_base_of_v<Type, Tys> && ...);

using TypePtrArray = std::vector<Type *>;

/// The instances of the Type class are immutable: once they are created,
/// they are never changed. Also note that only one instance of a particular
/// type is ever created. Thus seeing if two types are equal is a matter of
/// doing a trivial pointer comparison. To enforce that no two equal instances
/// are created, Type instances can only be created via static factory methods
/// in class Type and in derived classes. Once allocated, Types are never
/// free'd.
///
class Type {
  public:
    ///
    /// \brief TypeID of built-in primitive types.
    /// Definition of all of the base types for the Type system. Based on this
    /// value, you can cast to a class defined in DerivedTypes.hh
    ///
    enum class TypeID {
        // Primitive Types
        Void,   ///< type with no size
        Float,  ///< 32-bit floating point type
        Double, ///< 64-bit floating point type
        Int1,   ///< 1-bit integer
        UInt8,  ///< 8-bit unsigned integer
        SInt8,  ///< 8-bit signed integer
        UInt16, ///< 16-bit unsigned integer
        SInt16, ///< 16-bit signed integer
        UInt32, ///< 32-bit unsigned integer
        SInt32, ///< 32-bit signed integer
        UInt64, ///< 64-bit unsigned integer
        SInt64, ///< 64-bit signed integer
        Label,  ///< Labels
        Token,  ///< Tokens

        // Derived Types from DerivedTypes.hh
        Function, ///< Functions
        Pointer,  ///< Pointers
        Struct,   ///< Structures
        Array,    ///< Arrays
    };

  protected:
    friend class TypeContext;
    explicit Type(TypeContext &C, TypeID tid) : context(C), ID{tid} {}

    unsigned getSubclassData() const { return subClassData; }

    void setSubclassData(unsigned val)
    {
        subClassData = val;
        splc_assert(subClassData == val) << "subclass data too large for field";
    }

    unsigned numContainedTys = 0;
    Type *const *containedTys = nullptr;

  private:
    TypeContext &context;
    TypeID ID;
    unsigned subClassData;

  public:
    virtual ~Type() = default;

    friend std::ostream &operator<<(std::ostream &os, const Type &type)
    {
        return os << "Type: " << static_cast<int>(type.ID);
    }

    //===----------------------------------------------------------------------===//
    // Accessors
    TypeContext &getContext() const { return context; }

    TypeID getTypeID() const { return ID; }

    bool isVoidTy() const { return getTypeID() == TypeID::Void; }

    bool isFloatTy() const { return getTypeID() == TypeID::Float; }

    bool isDoubleTy() const { return getTypeID() == TypeID::Double; }

    bool isFloatingPointTy() const { return isFloatTy() || isDoubleTy(); }

    bool isLabelTy() const { return getTypeID() == TypeID::Label; }

    bool isTokenTy() const { return getTypeID() == TypeID::Token; }

    bool isInt1Ty() const { return getTypeID() == TypeID::Int1; }

    bool isUInt8Ty() const { return getTypeID() == TypeID::UInt8; }

    bool isUInt16Ty() const { return getTypeID() == TypeID::UInt16; }

    bool isUInt32Ty() const { return getTypeID() == TypeID::UInt32; }

    bool isUInt64Ty() const { return getTypeID() == TypeID::UInt64; }

    bool isSInt8Ty() const { return getTypeID() == TypeID::SInt8; }

    bool isSInt16Ty() const { return getTypeID() == TypeID::SInt16; }

    bool isSInt32Ty() const { return getTypeID() == TypeID::SInt32; }

    bool isSInt64Ty() const { return getTypeID() == TypeID::SInt64; }

    bool isInt8Ty() const { return isUInt8Ty() || isSInt8Ty(); }

    bool isInt16Ty() const { return isUInt16Ty() || isSInt16Ty(); }

    bool isInt32Ty() const { return isUInt32Ty() || isSInt32Ty(); }

    bool isInt64Ty() const { return isUInt64Ty() || isSInt64Ty(); }

    bool isUIntTy() const
    {
        return isUInt8Ty() || isUInt16Ty() || isUInt32Ty() || isUInt64Ty();
    }

    bool isSIntTy() const
    {
        return isSInt8Ty() || isSInt16Ty() || isSInt32Ty() || isSInt64Ty();
    }

    bool isIntTy() const { return isUIntTy() || isSIntTy() || isInt1Ty(); }

    bool isFunctionTy() const { return getTypeID() == TypeID::Function; }

    bool isPointerTy() const { return getTypeID() == TypeID::Pointer; }

    bool isIntOrPtrTy() const { return isIntTy() || isPointerTy(); }

    bool isStructTy() const { return getTypeID() == TypeID::Struct; }

    bool isArrayTy() const { return getTypeID() == TypeID::Array; }

    bool isEmptyTy() const;

    /// Return true if the type is "first class", meaning it is a valid type for
    /// a Value.
    bool isFirstClassType() const { return !isFunctionTy() && !isVoidTy(); }

    /// Return true if the type is a valid type for a register in codegen. This
    /// includes all first-class types except struct and array types.
    bool isSingleValueType() const
    {
        return isFloatingPointTy() || isIntTy() || isPointerTy();
    }

    bool isAggregateType() const { return isStructTy() || isArrayTy(); }

    /// Return true if it makes sense to take the size of this type.
    bool isSized() const
    {
        if (isIntTy() || isFloatTy() || isPointerTy())
            return true;

        if (!isStructTy() && !isArrayTy())
            return false;

        return isSizedDerivedType();
    }

    size_t getPrimitiveSizeInBits() const;

    //===----------------------------------------------------------------------===//
    // Type Iteration support.
    using subtype_iterator = Type *const *;
    subtype_iterator subtype_begin() const { return containedTys; }
    subtype_iterator subtype_end() const
    {
        return &containedTys[numContainedTys];
    }
    TypePtrArray subtypes() const { return {subtype_begin(), subtype_end()}; }

    using subtype_reverse_iterator = std::reverse_iterator<subtype_iterator>;

    subtype_reverse_iterator subtype_rbegin() const
    {
        return subtype_reverse_iterator(subtype_end());
    }

    subtype_reverse_iterator subtype_rend() const
    {
        return subtype_reverse_iterator(subtype_begin());
    }

    Type *getContainedType(unsigned i) const
    {
        splc_assert(i < numContainedTys)
            << "index out of range: " << i << " of " << numContainedTys;
        return containedTys[i];
    }

    unsigned getIntegerBitWidth() const;

    Type *getFunctionParamType(unsigned i) const;

    unsigned getFunctionNumParams() const;

    bool isFunctionVarArg() const;

    std::string_view getStructName() const;
    unsigned getStructNumElements() const;
    Type *getStructElementType(unsigned i) const;

    uint64_t getArrayNumElements() const;

    Type *getArrayElementType() const
    {
        splc_assert(isArrayTy()) << "getArrayElementType() called on non-array type.";
        return containedTys[0];
    }

    static Type *getPrimitiveType(TypeContext &C, TypeID ID);

    static Type *getFloatTy(TypeContext &C);
    static Type *getDoubleTy(TypeContext &C);
    static Type *getVoidTy(TypeContext &C);
    static Type *getLabelTy(TypeContext &C);
    static Type *getTokenTy(TypeContext &C);
    static Type *getInt1Ty(TypeContext &C);
    static Type *getUInt8Ty(TypeContext &C);
    static Type *getSInt8Ty(TypeContext &C);
    static Type *getUInt16Ty(TypeContext &C);
    static Type *getSInt16Ty(TypeContext &C);
    static Type *getUInt32Ty(TypeContext &C);
    static Type *getSInt32Ty(TypeContext &C);
    static Type *getUInt64Ty(TypeContext &C);
    static Type *getSInt64Ty(TypeContext &C);

    /// Return a pointer to the current type.
    PointerType *getPointerTo() const;

  private:
    bool isSizedDerivedType() const;
};

using TypeID = Type::TypeID;

/// Reference: https://stackoverflow.com/a/24586587
inline std::string randomTypeName(std::string::size_type length)
{
    static std::string chrs{"0123456789"
                            "abcdefghijklmnopqrstuvwxyz"
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"};

    thread_local static std::mt19937 rg{std::random_device{}()};
    thread_local static std::uniform_int_distribution<std::string::size_type>
        pick(0, std::size(chrs) - 2);

    std::string s;

    s.reserve(length);

    while (length--)
        s += chrs[pick(rg)];

    return s;
}

// TODO: add:
//  - Type comparison
//  - Type promotion
//  - Implicit Cast/Explicit Cast

} // namespace splc

#endif // __SPLC_AST_TYPE_HH__