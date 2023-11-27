#include "utils.h"
#include "dir_search.h"
#include "lex.yy.h"
#include "syntax.tab.h"

#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int splc_enable_diag = 0;

int splc_file_node_cnt = 0;

util_file_node *splc_all_file_nodes = NULL;

util_file_node splc_file_node_stack = NULL;

/* Return an array of lines fetched. No newline character will be present. */
static char *fetchline(FILE *file, int linebegin)
{
    char *lineptr = (char *)NULL;
    for (int cur = 0; cur < linebegin; ++cur)
    {
        free(lineptr);
        lineptr = (char *)NULL;
        size_t n = 0;
        if (getline(&lineptr, &n, file) < 0)
            break;
    }
    /* Handling newline and EOF */
    size_t linelen = strlen(lineptr);
    if (linelen > 0 && lineptr[linelen - 1] == '\n')
    {
        lineptr[linelen - 1] = '\0';
        linelen--;
    }
    if (linelen > 0 && lineptr[linelen - 1] == '\r')
    {
        lineptr[linelen - 1] = '\0';
        linelen--;
    }
    return lineptr;
}

static const char *get_splc_error_color_code(error_t type)
{
    const char *color_code = "\033[31m";
    switch (type)
    {
    case SPLC_ERR_FATAL:
    case SPLC_ERR_UNIV:
    case SPLC_ERR_A:
    case SPLC_ERR_B:
    case SPLC_MACRO_ERROR:
        color_code = "\033[91m";
        break;
    case SPLC_WARN:
    case SPLC_MACRO_WARN:
        color_code = "\033[95m";
        break;
    case SPLC_NOTE:
        color_code = "\033[96m";
        break;
    case SPLC_DIAG:
        color_code = "\033[93m";
        break;
    default:
        color_code = "\033[96m";
        break;
    }
    return color_code;
}

static void print_colored_line(error_t type, const char *line, int linebegin, int colbegin, int colend)
{
    const char *color_code = get_splc_error_color_code(type);
    fprintf(stderr, "%8d |", linebegin);

    for (int i = 0; i < colbegin - 1; ++i)
        fprintf(stderr, "%c", line[i]);

    fprintf(stderr, "%s", color_code);
    for (int i = colbegin - 1; i < colend; ++i)
        fprintf(stderr, "%c", line[i]);
    fprintf(stderr, "\033[0m");

    for (int i = colend; line[i] != '\0'; ++i)
        fprintf(stderr, "%c", line[i]);
    fprintf(stderr, "\n");
}

static void print_indicator(error_t type, int colbegin, int colend)
{
    // fprintf(stderr, "Accepted parameters: %d %d\n", colbegin, colend);
    const char *color_code = get_splc_error_color_code(type);

    fprintf(stderr, "         |");

    for (int i = 1; i < colbegin; ++i)
        fprintf(stderr, " ");

    fprintf(stderr, "%s^", color_code);
    for (int i = colbegin + 1; i <= colend; ++i)
        fprintf(stderr, "~");
    fprintf(stderr, "\033[0m\n");

    return;
}

static char *splc_get_msg_type_prefix(error_t type)
{
    const char *type_name = "undefined message";
    switch (type)
    {
    case SPLC_ERR_FATAL:
        type_name = "fatal error";
        break;
    case SPLC_ERR_UNIV:
    case SPLC_ERR_A:
    case SPLC_ERR_B:
        type_name = "error";
        break;
    case SPLC_WARN:
        type_name = "warning";
        break;
    case SPLC_NOTE:
        type_name = "note";
        break;
    case SPLC_DIAG:
        type_name = "diagnostics";
        break;
    case SPLC_MACRO_ERROR:
        type_name = "error";
        break;
    case SPLC_MACRO_WARN:
        type_name = "warning";
        break;
    default:
        type_name = "fatal error";
        break;
    }
    return strdup(type_name);
}

static char *splc_get_msg_type_suffix(error_t type)
{
    char *type_suffix = NULL;
    switch (type)
    {
    case SPLC_ERR_FATAL:
        type_suffix = NULL;
        break;
    case SPLC_ERR_UNIV:
        type_suffix = NULL;
    case SPLC_ERR_A:
        type_suffix = "A";
        break;
    case SPLC_ERR_B:
        type_suffix = "B";
        break;
    case SPLC_WARN:
        type_suffix = NULL;
        break;
    case SPLC_NOTE:
        type_suffix = NULL;
        break;
    case SPLC_DIAG:
        type_suffix = NULL;
        break;
    case SPLC_MACRO_ERROR:
        type_suffix = "Wmacro-error";
        break;
    case SPLC_MACRO_WARN:
        type_suffix = "Wmacro-warning";
        break;
    default:
        type_suffix = NULL;
        break;
    }
    return (type_suffix != NULL) ? strdup(type_suffix) : NULL;
}

static void _builtin_splc_handle_msg_noloc(error_t type, const char *msg)
{
    const char *color_code = get_splc_error_color_code(type);
    char *type_name = splc_get_msg_type_prefix(type);
    char *type_suffix = splc_get_msg_type_suffix(type);
    const char *filename = (splc_file_node_stack != NULL) ? splc_file_node_stack->filename : progname;
    fprintf(stderr, "\033[1m%s\033[0m: %s%s:\033[0m %s", filename, color_code, type_name, msg);
    if (type_suffix != NULL)
    {
        fprintf(stderr, " [%s%s\033[0m]", color_code, type_suffix);
    }
    fprintf(stderr, "\n");
    free(type_name);
    free(type_suffix);

    return;
}

static void _builtin_splc_handle_msg(error_t type, const splc_loc *const location, const char *msg)
{
    // fprintf(stderr, "msg param %d %d - %d %d\n", location->linebegin, location->colbegin, location->lineend,
    // location->colend);
    const char *color_code = get_splc_error_color_code(type);
    char *type_name = splc_get_msg_type_prefix(type);
    char *type_suffix = splc_get_msg_type_suffix(type);
    const char *const orig_file = splc_all_file_nodes[location->fid]->filename;
    fprintf(stderr, "\033[1m%s\033[0m:%d:%d: %s%s:\033[0m %s", orig_file, location->linebegin, location->colbegin,
            color_code, type_name, msg);
    if (type_suffix != NULL)
    {
        fprintf(stderr, " [%s%s\033[0m]", color_code, type_suffix);
    }
    fprintf(stderr, "\n");
    free(type_name);
    free(type_suffix);

    FILE *file = NULL;
    if ((file = fopen(orig_file, "r")) == NULL)
    {
        SPLC_FERROR_NOLOC(SPLC_ERR_FATAL, "file no longer exists: %s\n", orig_file);
        return;
    }
    char *line = fetchline(file, location->linebegin);
    fclose(file);

    int line_len = (int)strlen(line);

    int t_colend = location->colbegin;
    if (location->lineend == location->linebegin && location->colend > location->colbegin)
        t_colend = location->colend - 1;
    else if (location->lineend != location->linebegin)
        t_colend = line_len;

    print_colored_line(type, line, location->linebegin, location->colbegin, t_colend);
    print_indicator(type, location->colbegin, t_colend);
    free(line);

    return;
}

/* If passed a NULL location or location that has fid=1, then the trace information will not be printed. */
static void splc_handle_msg(error_t type, const splc_loc *const location, const char *msg)
{
    if (location != NULL && !SPLC_IS_LOC_ROOT(*location))
        _builtin_splc_handle_msg(type, location, msg);
    else
        _builtin_splc_handle_msg_noloc(type, msg);
    return;
}

static const char *splc_get_trace_string(trace_t type)
{
    const char *type_str = "UNDEFINED";
    switch (type)
    {
    case SPLTR_MACRO:
        type_str = "macro";
        break;
    case SPLTR_FILE_INCL:
        type_str = "file included ";
        break;
    case SPLTR_FUNCTION:
        type_str = "function";
        break;
    case SPLTR_STRUCT:
        type_str = "struct";
        break;
    default:
        type_str = "unknown structure";
        break;
    }
    return type_str;
}

void splctrace(trace_t type, int show_source, const char *name)
{
    const char *type_str = splc_get_trace_string(type);
    fprintf(stderr, "%s%sIn %s \033[1m'%s'\033[0m:%d:\n", show_source != 0 ? splc_file_node_stack->filename : "",
            show_source != 0 ? ": " : "", type_str, name, splc_file_node_stack->yylineno);
    return;
}

static void _builtin_splcerror(error_t type, const splc_loc *const location, const char *msg)
{
    update_error(1);
    splc_handle_msg(type, location, msg);
}

static void _builtin_splcwarn(const splc_loc *const location, const char *msg)
{
    update_warning(1);
    splc_handle_msg(SPLC_WARN, location, msg);
}

static void _builtin_splcnote(const splc_loc *const location, const char *msg)
{
    splc_handle_msg(SPLC_NOTE, location, msg);
}

void _builtin_splcdiag(const char *msg)
{
    splc_handle_msg(SPLC_DIAG, NULL, msg);
}

static void _builtin_print_file_trace(util_file_node node)
{
    if (node == NULL || SPLC_IS_LOC_ROOT(node->location))
    {
        return;
    }
    SPLC_ASSERT(node->next->next != NULL);
    util_file_node top = node;
    const char *suffix = (top->next->next == NULL) ? ":\n" : ",\n";
    fprintf(stderr, "In file included from \033[1m%s\033[0m:%d%s", top->next->filename, top->yylineno, suffix);
    top = top->next;
    while (top && !SPLC_IS_LOC_ROOT(top->location))
    {
        SPLC_ASSERT(top->next != NULL);
        suffix = (top->next->next == NULL) ? ":\n" : ",\n";
        fprintf(stderr, "                 from \033[1m%s\033[0m:%d%s", top->next->filename, top->yylineno, suffix);
        top = top->next;
    }
}

static inline void print_file_trace(util_file_node node)
{
    if (node == NULL)
        _builtin_print_file_trace(splc_file_node_stack);
    else
        _builtin_print_file_trace(node);
}

void splcfail(const char *msg)
{
    splcerror_noloc(SPLC_ERR_FATAL, msg);
    abort();
}

void splcerror(error_t type, const splc_loc location, const char *msg)
{
    print_file_trace(splc_all_file_nodes[location.fid]);
    _builtin_splcerror(type, &location, msg);
}

void splcerror_noloc(error_t type, const char *msg)
{
    update_error(1);
    _builtin_splcerror(type, NULL, msg);
}

void splcwarn(const splc_loc location, const char *msg)
{
    print_file_trace(splc_all_file_nodes[location.fid]);
    _builtin_splcwarn(&location, msg);
}

void splcwarn_noloc(const char *msg)
{
    print_file_trace(NULL);
    _builtin_splcwarn(NULL, msg);
}

void splcnote(const splc_loc location, const char *msg)
{
    print_file_trace(splc_all_file_nodes[location.fid]);
    _builtin_splcnote(&location, msg);
}

void splcdiag(const char *msg)
{
    if (splc_enable_diag)
        _builtin_splcdiag(msg);
}

static int _builtin_splc_enter_file(const char *restrict _filename, const splc_loc *const location)
{
    FILE *new_file = NULL;
    char *filename = NULL; /* This contains actually the full path of file. After got from splc_search_incl_dirs, there
                              is no need to free it, as it will be directly placed in the file node. */
    if ((filename = splc_search_incl_dirs(_filename)) == NULL || (new_file = fopen(filename, "r")) == NULL)
    {
        const char *msg = "failed to include file. Please check whether the path exists or this program has access right.";
        splcerror(SPLC_ERR_FATAL, *location, msg);
        return -1;
    }
    SPLC_FDIAG("the included file has been identified: %s", filename);

    util_file_node node = (util_file_node)malloc(sizeof(util_file_node_struct));
    node->fid = splc_file_node_cnt++;
    node->filename = filename;
    node->file = new_file;
    node->file_buffer = yy_create_buffer(new_file, YY_BUF_SIZE);
    node->location = (location != NULL) ? *location : SPLC_ROOT_LOC;
    node->yylineno = yylineno;
    node->yycolno = yycolno;
    node->next = splc_file_node_stack;
    splc_file_node_stack = node;

    splc_all_file_nodes = (util_file_node *)realloc(splc_all_file_nodes, splc_file_node_cnt * sizeof(util_file_node));
    SPLC_ALLOC_PTR_CHECK(splc_all_file_nodes, "out of memory when opening files");
    splc_all_file_nodes[splc_file_node_cnt - 1] = node;

    yy_switch_to_buffer(node->file_buffer);
    yynewfile = 1;
    yylineno = 1;
    yycolno = 1;

    return 0;
}

int splc_enter_root(const char *restrict _filename)
{
    return _builtin_splc_enter_file(_filename, NULL);
}

int splc_enter_file(const char *restrict _filename, const splc_loc location)
{
    return _builtin_splc_enter_file(_filename, &location);
}

int _builtin_splc_exit_file()
{
    if (splc_file_node_stack == NULL)
    {
        return 1;
    }

    util_file_node tmp = splc_file_node_stack;

    yy_delete_buffer(tmp->file_buffer);
    fclose(tmp->file);

    splc_file_node_stack = tmp->next;
    if (splc_file_node_stack != NULL)
    {
        yy_switch_to_buffer(splc_file_node_stack->file_buffer);
        yynewfile = 0;
        /* Handle yylloc */
        yylloc.first_line = tmp->location.linebegin;
        yylloc.first_column = tmp->location.colbegin;
        yylloc.last_line = tmp->location.lineend;
        yylloc.last_column = tmp->location.colend;
        yylineno = tmp->yylineno;
        yycolno = tmp->yycolno;
    }

    return splc_file_node_stack == NULL;
}

int splc_exit_file()
{
    return _builtin_splc_exit_file();
}

const char *const splc_get_node_filename(int fid)
{
    return splc_all_file_nodes[fid]->filename;
}

void update_error(int val)
{
    err_count += val;
}

void update_warning(int val)
{
    warn_count += val;
}