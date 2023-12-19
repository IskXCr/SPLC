#include "Core/Base.hh"
#include "Core/System.hh"
#include "IO/Parser.hh"

#include "Translation/TranslationManager.hh"

namespace splc {

void TranslationManager::startTranslationRecord()
{
    tunit = createPtr<TranslationUnit>();
}

void TranslationManager::endTranslationRecord() {}

void TranslationManager::reset() { tunit.reset(); }

void TranslationManager::pushASTContext()
{
    // TODO
}

void TranslationManager::popASTContext()
{
    // TODO
}

void TranslationManager::getCurrentASTContext()
{
    // TODO
}

Ptr<TranslationContext> TranslationManager::getCurrentTranslationContext()
{
    return tunit->translationContextManager.getCurrentContext();
}

const std::string &TranslationManager::getCurrentTranslationContextName()
{
    return tunit->translationContextManager.getCurrentContext()->name;
}

Ptr<TranslationContext>
TranslationManager::pushTranslationContext(const Location *intrLoc_,
                                           std::string_view fileName_)
{
    Ptr<TranslationContext> context =
        tunit->translationContextManager.pushContext(intrLoc_, fileName_);
    return context;
}

Ptr<TranslationContext>
TranslationManager::pushTranslationContext(const Location *intrLoc_,
                                           std::string_view macroName_,
                                           std::string_view content_)
{
    Ptr<TranslationContext> context =
        tunit->translationContextManager.pushContext(intrLoc_, macroName_,
                                                     content_);
    // yy_buffer_state *newState =
    // scanner->yy_create_buffer(context->inputStream.get(), SPLC_BUF_SIZE);
    // scanner->yypush_buffer_state(newState);
    return context;
}

Ptr<TranslationContext> TranslationManager::popTranslationContext()
{
    Ptr<TranslationContext> context =
        tunit->translationContextManager.popContext();
    // scanner->yypop_buffer_state();
    return context;
}

Ptr<TranslationUnit> TranslationManager::getTranslationUnit() { return tunit; }

TranslationLogger::TranslationLogger(const Ptr<const TranslationUnit> tunit_,
                                     const bool trace_, const Location *locPtr_,
                                     const Level level_)
    : Logger{true, level_, locPtr_}
{
    // TODO: allow debug trace
}

TranslationLogger::~TranslationLogger()
{
    // TODO
}

} // namespace splc