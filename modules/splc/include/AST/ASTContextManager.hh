#ifndef __SPLC_AST_ASTCONTEXTMANAGER_HH__
#define __SPLC_AST_ASTCONTEXTMANAGER_HH__ 1

#include <string>
#include <string_view>
#include <vector>

#include "Core/splc.hh"

#include "AST/ASTBase.hh"
#include "AST/ASTCommons.hh"
#include "AST/ASTContext.hh"

namespace splc {

class ASTContextManager {
  public:
    ///
    /// \brief Push a context into the stack.
    ///
    Ptr<ASTContext> pushContext() noexcept
    {
        auto context = makeSharedPtr<ASTContext>(contextStack.size());
        contextStack.push_back(context);
        return context;
    }

    ///
    /// \brief Pop a context and return from the stack.
    ///
    Ptr<ASTContext> popContext() noexcept
    {
        auto context = contextStack.back();
        contextStack.pop_back();
        return context;
    }

    bool isSymbolDeclared(std::string_view name_) const noexcept;

    bool isSymbolDefined(std::string_view name_) const noexcept;

    SymbolEntry getSymbol(std::string_view name_);

    ///
    /// \brief Register a `SymbolEntry` at the top context.
    ///
    SymbolEntry registerSymbol(SymbolEntry::EntrySummary summary_,
                               std::string_view name_, Ptr<Type> type_,
                               bool defined_, const Location *location_,
                               ASTValueType value_ = ASTValueType{},
                               Ptr<AST> body_ = nullptr);

    ///
    /// \brief Provide a convenient way to access stack elements
    ///
    Ptr<ASTContext> operator[](size_t idx)
    {
        return contextStack[contextStack.size() - idx - 1];
    }

    Ptr<const ASTContext> operator[](size_t idx) const noexcept
    {
        return contextStack[contextStack.size() - idx - 1];
    }

    std::vector<Ptr<ASTContext>> &getContextStack() noexcept
    {
        return contextStack;
    }

    const std::vector<Ptr<ASTContext>> &getContextStack() const noexcept
    {
        return contextStack;
    }

    bool contextStackEmpty() const noexcept { return contextStack.empty(); }

    size_t contextStackSize() const noexcept { return contextStack.size(); }

  protected:
    std::vector<Ptr<ASTContext>> contextStack;
};

} // namespace splc

#endif // __SPLC_AST_ASTCONTEXTMANAGER_HH__