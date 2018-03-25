set(CMAKE_SHARED_LIBRARY_SUFFIX ".so")
set(CMAKE_STATIC_LIBRARY_SUFFIX ".a")

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

###
# sanitize "//" in string
function (SANITIZE_DBL_SLASH str_in str_out)
  string(REPLACE "//" "/" _str "${str_in}")
  set("${str_out}" "${_str}" PARENT_SCOPE)

endfunction()

###
# sanitize "//" in the list of library pathnames built by cmake
function (SANITIZE_DBL_SLASH_FROM_LIST list_in list_out)
  foreach(item IN LISTS list_in)
    SANITIZE_DBL_SLASH("${item}" item)
    list(APPEND _list "${item}")
  endforeach(item)
  set("${list_out}" "${_list}" PARENT_SCOPE)

endfunction()


function (TRACK_CHAIN_IF_ARCHIVE_LIB pkgname libnames_in libnames_out is_found is_static)
  SANITIZE_DBL_SLASH_FROM_LIST("${libnames_in}" _libnames)
  message("${_libnames}")

  ###
  # make a list of directories
  execute_process(COMMAND          pkg-config --libs-only-L ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " -L" ";" _libdir_list " ${_output_value}")
  list(REMOVE_AT _libdir_list 0)
  #
  # often compiler default path is omitted in -L option.
  # include the destination of the package installation.
  execute_process(COMMAND          pkg-config --variable=libdir ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  list(APPEND _libdir_list "${_output_value}")

  ### 
  # make a list of shared libraries requested by pkg-config
  execute_process(COMMAND          pkg-config --libs-only-l ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " -l" " lib" _output_value " ${_output_value}")
  string(REGEX REPLACE "^ " "" _output_value " ${_output_value}")
  # message("shared libs: ${_output_value}")
  string(REPLACE " " "${CMAKE_SHARED_LIBRARY_SUFFIX};" _output_list_shared "${_output_value}${CMAKE_SHARED_LIBRARY_SUFFIX}")
  # list(REMOVE_AT _output_list_shared len)
  message("shared libs of package ${pkgname}: ${_output_list_shared}")

  ### 
  # make a list of static libraries requested by pkg-config
  execute_process(COMMAND          pkg-config --libs-only-l --static ${pkgname}
                  RESULT_VARIABLE  _result_value
                  OUTPUT_VARIABLE  _output_value
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE " -l" " lib" _output_value " ${_output_value}")
  string(REGEX REPLACE "^ " "" _output_value " ${_output_value}")
  # message("static libs: ${_output_value}")
  string(REPLACE " " "${CMAKE_STATIC_LIBRARY_SUFFIX};" _output_list_static "${_output_value}${CMAKE_STATIC_LIBRARY_SUFFIX}")
  # list(REMOVE_AT _output_list_static len)
  message("static libs of package ${pkgname}: ${_output_list_static}")

  ###
  # check for shared libraries 
  set(_found_all_libs_as_shared TRUE)
  message("${_libnames}")
  set(_libnames_tmp "${_libnames}")
  foreach (alib IN LISTS _output_list_shared)
    message("  search shared lib: ${alib}")
    set(_found_this_lib_as_shared FALSE)
    foreach (adir IN LISTS _libdir_list)
      message("  shared lib dir: ${adir}")
      set(alib_pathname "${adir}/${alib}")
      SANITIZE_DBL_SLASH("${alib_pathname}" alib_pathname)
      message("    search pathname ${alib_pathname} in ${_libnames_tmp}")

      list(FIND _libnames_tmp "${alib_pathname}" _index)
      if(_index GREATER -1)
        message("      found")
        set(_found_this_lib_as_shared TRUE)
        list(REMOVE_AT _libnames_tmp _index)
        break()
      endif()
    endforeach(adir)
    if (NOT _found_this_lib_as_shared)
      set(_found_all_libs_as_shared FALSE)
    endif()
  endforeach(alib)
  if (_found_all_libs_as_shared)
    set(${libnames_out} "${_libnames_tmp}" PARENT_SCOPE)
    set(${is_found} TRUE PARENT_SCOPE)
    set(${is_static} FALSE PARENT_SCOPE)
    return()
  endif()

  ###
  # check for shared libraries 
  set(_found_all_libs_as_static TRUE)
  set(_libnames_tmp "${_libnames}")
  foreach (alib IN LISTS _output_list_static)
    message("  static lib: ${alib}")
    set(_found_this_lib_as_static FALSE)
    foreach (adir IN LISTS _libdir_list)
      message("  static lib dir: ${adir}")
      set(alib_pathname "${adir}/${alib}")
      SANITIZE_DBL_SLASH("${alib_pathname}" alib_pathname)
      message("    search pathname ${alib_pathname} in ${_libnames_tmp}")

      list(FIND _libnames_tmp "${alib_pathname}" _index)
      if(_index GREATER -1)
        message("      found")
        set(_found_this_lib_as_static TRUE)
        list(REMOVE_AT _libnames_tmp _index)
        break()
      endif()
    endforeach(adir)
    if (NOT _found_this_lib_as_static)
      set(_found_all_libs_as_static FALSE)
    endif()
  endforeach(alib)
  if (_found_all_libs_as_shared)
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
