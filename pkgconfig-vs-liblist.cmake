set(CMAKE_SHARED_LIBRARY_SUFFIX ".so")
set(CMAKE_STATIC_LIBRARY_SUFFIX ".a")
set(PKG_CONFIG_EXECUTABLE "pkg-config")

function (GET_LIST_REQ_PKGS pkgname l)
  execute_process(COMMAND          pkg-config --print-requires --print-requires-private ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE "\n" ";" _output_list "${_output_value}")
  foreach(v IN LISTS _output_list)
    string(REGEX REPLACE " .*$" "" v "${v}")
    list(APPEND ${l} "${v}")
  endforeach(v)
  set(${l} "${${l}}" PARENT_SCOPE)
endfunction()

##########################################################################################
# sanitize "//" in string
function (SANITIZE_DBL_SLASH str_in str_out)
  string(REPLACE "//" "/" _str "${str_in}")
  set("${str_out}" "${_str}" PARENT_SCOPE)

endfunction()

##########################################################################################
# sanitize "//" in the list of library pathnames built by cmake
function (SANITIZE_DBL_SLASH_FROM_LIST list_in list_out)
  foreach(item IN LISTS list_in)
    SANITIZE_DBL_SLASH("${item}" item)
    list(APPEND _list "${item}")
  endforeach(item)
  set("${list_out}" "${_list}" PARENT_SCOPE)

endfunction()

##########################################################################################
# make a list of directories
function (GET_DIR_LIST_PKG_CONFIG pkgname libdir_list)
  execute_process(COMMAND          ${PKG_CONFIG_EXECUTABLE} --libs-only-L ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " -L" ";" _libdir_list " ${_output_value}")
  list(REMOVE_AT _libdir_list 0)
  #
  # often compiler default path is omitted in -L option.
  # include the destination of the package installation.
  execute_process(COMMAND          ${PKG_CONFIG_EXECUTABLE} --variable=libdir ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  list(APPEND _libdir_list "${_output_value}")

  SANITIZE_DBL_SLASH_FROM_LIST("${_libdir_list}" _libdir_list)
  set("${libdir_list}" "${_libdir_list}" PARENT_SCOPE)

endfunction()

##########################################################################################
# make a list of libraries
function (GET_LIB_LIST_PKG_CONFIG pkgname output_list lib_suffix pkg_config_flag)
  execute_process(COMMAND          pkg-config --libs-only-l "${pkg_config_flag}" ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " -l" " lib" _output_value " ${_output_value}")
  string(REGEX REPLACE "^ " "" _output_value " ${_output_value}")
  # message("shared libs: ${_output_value}")
  string(REPLACE " " "${lib_suffix};" _output_list "${_output_value}${lib_suffix}")
  set("${output_list}" "${_output_list}" PARENT_SCOPE)

endfunction()


##########################################################################################
# search a basename + dirlist from pathlist
function (FIND_BASE_AND_DIRLIST_FROM_PATHLIST alib dirs pathnames_in pathnames_out result)
  set("${result}" FALSE PARENT_SCOPE)
  foreach (adir IN LISTS dirs)
    message("  shared lib dir: ${adir}")
    set(alib_pathname "${adir}/${alib}")
    SANITIZE_DBL_SLASH("${alib_pathname}" alib_pathname)
    message("    search pathname ${alib_pathname} in ${pathnames_in}")

    list(FIND pathnames_in "${alib_pathname}" _index)
    if(_index GREATER -1)
      message("      found")
      set("${result}" TRUE PARENT_SCOPE)
      list(REMOVE_AT pathnames_in _index)
      set("${pathnames_out}" "${pathnames_in}" PARENT_SCOPE)
      return()
    endif()
  endforeach(adir)

endfunction()

##########################################################################################
# search baselist + dirlist from pathlist
function (FIND_BASELIST_AND_DIRLIST_FROM_PATHLIST libs dirs pathnames_in pathnames_out result)
  set(${result} FALSE PARENT_SCOPE)
  set(_found_all_libs TRUE)
  set(_pathnames "${pathnames_in}")
  foreach (alib IN LISTS libs)
    message("  search shared lib: ${alib}")
    set(_found_this_lib FALSE)
    FIND_BASE_AND_DIRLIST_FROM_PATHLIST("${alib}" "${dirs}" "${_pathnames}" _pathnames _found_this_lib)
    if (NOT _found_this_lib)
      set(_found_all_libs FALSE)
    endif()
  endforeach(alib)
  if (_found_all_libs)
    set(${pathnames_out} "${_pathnames}" PARENT_SCOPE)
    set(${result} TRUE PARENT_SCOPE)
  endif()

endfunction()

##########################################################################################
#
function (TRACK_CHAIN_IF_ARCHIVE_LIB pkgname libnames_in libnames_out is_found is_static)
  SANITIZE_DBL_SLASH_FROM_LIST("${libnames_in}" _libnames)
  message("${_libnames}")

  GET_DIR_LIST_PKG_CONFIG(${pkgname} _libdir_list)
  message("${_libdir_list}")

  GET_LIB_LIST_PKG_CONFIG(${pkgname} _output_list_shared ${CMAKE_SHARED_LIBRARY_SUFFIX} "")
  message("shared libs of package ${pkgname}: ${_output_list_shared}")

  GET_LIB_LIST_PKG_CONFIG(${pkgname} _output_list_static ${CMAKE_STATIC_LIBRARY_SUFFIX} "--static")
  message("static libs of package ${pkgname}: ${_output_list_static}")

  ###
  # check for shared libraries 
  FIND_BASELIST_AND_DIRLIST_FROM_PATHLIST("${_output_list_shared}" "${_libdir_list}" "${_libnames}"
                                         _libnames_tmp _found_all_as_shared)
  if (_found_all_as_shared)
    set(${libnames_out} "${_libnames_tmp}" PARENT_SCOPE)
    set(${is_found} TRUE PARENT_SCOPE)
    set(${is_static} FALSE PARENT_SCOPE)
    return()
  endif()

  ###
  # check for static libraries 
  FIND_BASELIST_AND_DIRLIST_FROM_PATHLIST("${_output_list_static}" "${_libdir_list}" "${_libnames}"
                                         _libnames_tmp _found_all_as_static)
  if (_found_all_as_static)
    set(${libnames_out} "${_libnames_tmp}" PARENT_SCOPE)
    set(${is_found} TRUE PARENT_SCOPE)
    set(${is_static} TRUE PARENT_SCOPE)
    return()
  endif()


  set(${is_found} FALSE PARENT_SCOPE)
  set(${is_static} FALSE PARENT_SCOPE)
endfunction()


# GET_LIST_REQ_PKGS("mirclient" pkg_reqs)
set(libnames "/usr/lib/x86_64-linux-gnu/libmirclient.so;/usr/lib/x86_64-linux-gnu/libmircore.so;/usr/lib/libc.so;/usr/lib/libm.so")
TRACK_CHAIN_IF_ARCHIVE_LIB("mirclient" "${libnames}" libnames is_found is_static)
message("${libnames}")
message(${is_found})
message(${is_static})
