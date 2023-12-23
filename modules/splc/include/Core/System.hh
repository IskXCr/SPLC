#ifndef __SPLC_CORE_SYSTEM_HH__
#define __SPLC_CORE_SYSTEM_HH__ 1

#include <exception>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>

#include "Core/Utils/LocationWrapper.hh"

namespace splc {
class RuntimeError : public std::runtime_error {
  public:
    RuntimeError() = delete;
    RuntimeError(int code_, const std::string &msg_);
    RuntimeError(int code_, const Location &loc_, const std::string &msg_);
    virtual const char *what() const noexcept override;

    int getCode() const noexcept { return code; }
    const Location &getLocation() const noexcept { return loc; }
    const std::string &getMsg() const noexcept { return msg; }

  private:
    void formatMessage();
    int code;
    Location loc;
    std::string msg;
};

///
/// \brief This class represents the general semantic error encountered during
/// semantically analyzing the entire syntax tree.
///
class SemanticError : public std::runtime_error {
  public:
    SemanticError(const Location *loc_, const std::string &m)
        : std::runtime_error(m), loc{loc_ == nullptr ? Location{} : *loc_}
    {
    }

    SemanticError(const SemanticError &s)
        : std::runtime_error(s.what()), loc(s.loc)
    {
    }

    const Location loc;
};

} // namespace splc

/// Some mysterious designs in Flex
/// prohibit us from using the
/// Lexer.hh header, so it has been ignored.
#define SPLC_BUF_SIZE 16384

#endif // __SPLC_CORE_SYSTEM_HH__
