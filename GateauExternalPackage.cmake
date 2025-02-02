#       Copyright Pierre-Antoine LACAZE 2018 - 2020.
# Distributed under the Boost Software License, Version 1.0.
#    (See accompanying file LICENSE_1_0.txt or copy at
#          https://www.boost.org/LICENSE_1_0.txt)

# A wrapper over ExternalProject_Add that simplifies its use
include_guard()
include(ExternalProject)
include(GateauParseArguments)

# Create the directories needed to install the dependency dep
function(_gateau_prepare_external_dirs dep)
    gateau_external_root(d)
    gateau_create_dir("${d}/targets")
    gateau_external_download_dir("${dep}" d)
    gateau_create_dir("${d}")
    gateau_external_source_dir("${dep}" d)
    gateau_create_dir("${d}")
    gateau_external_install_prefix(d)
    gateau_create_dir("${d}")
    gateau_external_install_manifest_dir(d)
    gateau_create_dir("${d}")

    # several locations are used by externalproject for the build
    gateau_external_build_dir("${dep}" bd)
    set (_dirs
        "${bd}/build"
        "${bd}/stamp"
        "${bd}/tmp"
        "${bd}/ext/build")

    foreach(dir ${_dirs})
        gateau_create_dir("${dir}")
    endforeach()
endfunction()

# Path to the install manifest file
function(gateau_install_manifest_file dep out_file)
    gateau_external_install_manifest_dir(_manifest_dir)
    set(${out_file} "${_manifest_dir}/${dep}_install_manifest.txt" PARENT_SCOPE)
endfunction()

# Create a manifest of files that have been installed by a dep. This manifest
# will be kept for later uninstallation of the dep.
# The paths must be relative to the installation root.
function(gateau_create_install_manifest dep)
    gateau_install_manifest_file(${dep} manifest_file)
    string(REPLACE ";" "\n" files "${ARGN}")
    file(WRITE "${manifest_file}" "${files}")
endfunction()

# Create an uninstall script for the dep
function(gateau_configure_uninstall_script dep script)
    gateau_get(TEMPLATES_DIR templates)
    gateau_external_root(root_dir)
    set(uninstall_script "${root_dir}/targets/uninstall_${dep}.cmake")

    # Create an appropriate script
    set(GATEAU_DEP ${dep})
    gateau_to_identifier(${dep} GATEAU_DEP_ID)
    configure_file(
        "${templates}/UninstallDepScript.cmake.in"
        "${uninstall_script}"
        @ONLY
    )

    set(${script} "${uninstall_script}" PARENT_SCOPE)
endfunction()

# Create an uninstall target for the dep
function(gateau_configure_uninstall_target dep)
    gateau_configure_uninstall_script(${dep} uninstall_script)
    gateau_external_install_prefix(install_prefix)
    if (NOT TARGET uninstall_${dep})
        add_custom_target(uninstall_${dep}
            COMMENT "Uninstall the package ${dep}"
            COMMAND "${CMAKE_COMMAND}" -DGATEAU_DEP_INSTALL_PREFIX=${install_prefix} -P "${uninstall_script}"
            VERBATIM
        )
        set_target_properties(uninstall_${dep} PROPERTIES EXCLUDE_FROM_ALL TRUE)
    endif()
endfunction()

# Create update and reinstall targets for the dep
function(gateau_configure_update_reinstall_targets dep)
    gateau_external_root(root_dir)
    set(_script "${root_dir}/targets/update_reinstall_${dep}.cmake")
    if (EXISTS "${_script}")
        include("${_script}")
    endif()
endfunction()

# Uninstall a dep immediately
function(gateau_uninstall_dep dep)
    gateau_configure_uninstall_script(${dep} uninstall_script)
    gateau_external_install_prefix(install_prefix)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -DGATEAU_DEP_INSTALL_PREFIX=${install_prefix} -P "${uninstall_script}"
    )
endfunction()

# Update a dep immediately
function(gateau_update_dep dep)
    gateau_external_build_dir("${dep}" build_dir)
    set(ext_dir "${build_dir}/ext")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" --build "${ext_dir}/build"
    )
endfunction()

# Function that simplifies working with ExternalProject_Add
# It sets an external project up using the supplied available information and
# creates an install and uninstall target for later use.
#
# The list of recognized arguments is in the list of options at the begining
# of the function below, they mostly match the names and meaning of the one
# accepted by ExternalProject_add.
#
# The arguments used to configure the external project are retrieved from two
# sources: the arguments supplied to the function, as well as any variable in
# scope that has the form ${dep}_OPTION_NAME, where OPTION_NAME is a variable
# name from the 3 lists below.
#
# Unrecognized arguments will be passed as-is to ExternalProject_Add.
function(gateau_install_dependency dep)
    set(bool_options IN_SOURCE NO_EXTRACT NO_CONFIGURE NO_PATCH NO_UPDATE NO_BUILD NO_INSTALL)
    set(mono_options GIT TAG MD5 SOURCE_SUBDIR SHARED_LIBS)
    set(multi_options URL GIT_CONFIG CMAKE_CACHE_ARGS CMAKE_ARGS PATCH_COMMAND UPDATE_COMMAND CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND)

    # parse arguments supplied to the function and account for default arguments
    # stored in variables whose names are prefixed with "${dep}_"
    gateau_parse_arguments(SID ${dep} "${bool_options}" "${mono_options}" "${multi_options}" ${ARGN})

    # sanity checks, we need a few options and avoid ambiguities
    if (NOT SID_GIT AND NOT SID_URL)
        message(FATAL_ERROR "Missing source URL for dependency ${dep}")
    endif()

    # A package can either use an archive or a git repo, we ensure only one
    # of them is set
    if (SID_GIT AND SID_URL)
        if (${dep}_GIT)
            unset(SID_GIT)
            unset(SID_TAG)
        elseif(${dep}_URL)
            unset(SID_URL)
            unset(SID_MD5)
        endif()
    endif()

    # default to master branch if none supplied
    if (SID_GIT AND NOT SID_TAG)
        set(SID_TAG "master")
    endif()

    # where stuff will be built and installed: per package dirs
    gateau_external_root(external_root)
    gateau_external_download_dir("${dep}" download_dir)
    gateau_external_source_dir("${dep}" source_dir)
    gateau_external_build_dir("${dep}" build_dir)
    gateau_external_install_prefix(install_prefix)

    # A reasonable assumption is that if we stepped in this function the package
    # is currently not installed or its version is not compatible with what is
    # required. The safe bet is to reinstall it from scratch. For git archives,
    # the provided git tag will be used and the install will be reissued no matter
    # what (the prefix content will be deleted beforehand.
    if (SID_URL)
        file(REMOVE_RECURSE "${build_dir}")
    endif()

    # Also uninstall the previous installation
    gateau_uninstall_dep(${dep})

    # ensure the needed working directories exist
    _gateau_prepare_external_dirs(${dep})

    message(STATUS "Dependency ${dep} will be built in ${build_dir}")
    message(STATUS "Dependency ${dep} will be installed in ${install_prefix}")

    if (SID_SHARED_LIBS)
        message(STATUS "SHARED_LIBS explicitly set to ${SID_SHARED_LIBS} for ${dep}")
    else()
        message(STATUS "SHARED_LIBS not explicitly set for ${dep}, using ${BUILD_SHARED_LIBS}")
        set(SID_SHARED_LIBS ${BUILD_SHARED_LIBS})
    endif()

    # lists of lists are not supported, we use 
    string(REPLACE ";" "|" CMAKE_PREFIX_PATH_LST "${CMAKE_PREFIX_PATH}")
    string(REPLACE ";" "|" CMAKE_FIND_ROOT_PATH_LST "${CMAKE_FIND_ROOT_PATH}")

    # some cmake "cached" arguments that we wish to pass to ExternalProject_Add
    set(cache_args
        -DCMAKE_EXPORT_NO_PACKAGE_REGISTRY:BOOL=ON
        -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY:BOOL=ON
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY:BOOL=OFF
        "-DGATEAU_EXTERNAL_ROOT:PATH=${external_root}"
    )

    # pass compiler or toolchain file
    if (CMAKE_TOOLCHAIN_FILE)
        set(cmake_args
            "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
            "-DGATEAU_TOOLCHAIN_COMPILER_VERSION=${GATEAU_TOOLCHAIN_COMPILER_VERSION}")
    else()
        set(cmake_args
            "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
            "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
    endif()

    list(APPEND cmake_args
        "-DBUILD_SHARED_LIBS=${SID_SHARED_LIBS}"
        "-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH_LST}"
        "-DCMAKE_FIND_ROOT_PATH=${CMAKE_FIND_ROOT_PATH_LST}"
        "-DCMAKE_INSTALL_RPATH=${CMAKE_INSTALL_RPATH}"
        "-DCMAKE_INSTALL_PREFIX=${install_prefix}"
        -DCMAKE_FIND_DEBUG_MODE=ON
    )

    if (SID_CMAKE_CACHE_ARGS)
        list(APPEND cache_args ${SID_CMAKE_CACHE_ARGS})
    endif()

    # build type
    gateau_external_build_type(build_type)
    if (GENERATOR_IS_MULTI_CONFIG)
        list(APPEND cmake_args "-DCMAKE_CONFIGURATION_TYPES=${build_type}")
    else()
        list(APPEND cmake_args "-DCMAKE_BUILD_TYPE=${build_type}")
    endif()

    set(project_vars
        PREFIX "${build_dir}"
        STAMP_DIR "${build_dir}/stamp"
        TMP_DIR "${build_dir}/tmp"
        DOWNLOAD_DIR "${download_dir}"
        SOURCE_DIR "${source_dir}"
        INSTALL_DIR "${install_prefix}"
        LIST_SEPARATOR |
        CMAKE_CACHE_ARGS ${cache_args}
    )

    # Archive package
    if (SID_URL)
        list(APPEND project_vars URL "${SID_URL}")
         message(STATUS "${dep} will download file ${SID_URL}")
    endif()

    if (SID_MD5)
        list(APPEND project_vars URL_MD5 "${SID_MD5}")
    endif()

    # Git package, the version is used as a tag
    if (SID_GIT)
        list(APPEND project_vars GIT_REPOSITORY "${SID_GIT}")
        list(APPEND project_vars GIT_SHALLOW 1)
        list(APPEND project_vars GIT_TAG "${SID_TAG}")
        if (SID_GIT_CONFIG)
            list(APPEND project_vars GIT_CONFIG ${SID_GIT_CONFIG})
        endif()

        message(STATUS "${dep} will clone repo ${SID_GIT} branch ${SID_TAG}")
    endif()

    if (SID_IN_SOURCE)
        list(APPEND project_vars BUILD_IN_SOURCE 1)
    else()
        list(APPEND project_vars BINARY_DIR "${build_dir}/build")
    endif()

    if (SID_NO_EXTRACT)
        list(APPEND project_vars DOWNLOAD_NO_EXTRACT 1)
    endif()

    if (SID_SOURCE_SUBDIR)
        list(APPEND project_vars SOURCE_SUBDIR "${SID_SOURCE_SUBDIR}")
    endif()

    foreach(step UPDATE PATCH CONFIGURE BUILD INSTALL)
        if (SID_NO_${step})
            list(APPEND project_vars ${step}_COMMAND "")
        endif()
        if (SID_${step}_COMMAND)
            list(APPEND project_vars ${step}_COMMAND "${SID_${step}_COMMAND}")
        endif()
    endforeach()

    if (SID_CMAKE_ARGS)
        list(APPEND cmake_args "${SID_CMAKE_ARGS}")
    endif()
    list(APPEND project_vars CMAKE_ARGS ${cmake_args})

    if (SID_UNPARSED_ARGUMENTS)
        list(APPEND project_vars ${SID_UNPARSED_ARGUMENTS})
    endif()

    # We setup a mock project and execute it in a process to force immediate
    # installation of the package. ExternalProject_Add would defer installation
    # at build time instead and that would make using external dependencies for
    # the current project very difficult.
    set(ext_dir "${build_dir}/ext")

    # Generate a mock project to force immediate installation of the dep.
    # This project also creates an install manifest, used for uninstallation purpose
    set(GATEAU_DEP ${dep})
    gateau_to_identifier(${dep} GATEAU_DEP_ID)
    set(GATEAU_DEP_PROJECT_VARS "${project_vars}")
    set(GATEAU_DEP_BUILD_DIR "${build_dir}/build")
    set(GATEAU_DEP_INSTALL_DIR "${install_prefix}")
    gateau_get(TEMPLATES_DIR templates)

    configure_file(
        "${templates}/BuildDepProject.cmake.in"
        "${ext_dir}/CMakeLists.txt"
        @ONLY
    )
    configure_file(
        "${templates}/CreateDepInstallManifest.cmake.in"
        "${ext_dir}/CreateManifest.cmake"
        @ONLY
    )

    # We must set a toochain file if the project needs one
    if (CMAKE_TOOLCHAIN_FILE)
        set(toolchain_cmd -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
    endif()

    # Install right now
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -G "${CMAKE_GENERATOR}"
                                   -S "${ext_dir}"
                                   -B "${ext_dir}/build"
                                   ${toolchain_cmd}
        COMMAND_ECHO STDOUT
        RESULT_VARIABLE ext_result
    )

    if (NOT "${ext_result}" STREQUAL "0")
        message(SEND_ERROR "Could not configure ${dep} build: ${ext_result}")
        return()
    endif()

    execute_process(
        COMMAND "${CMAKE_COMMAND}" --build "${ext_dir}/build"
        COMMAND_ECHO STDOUT
        RESULT_VARIABLE ext_result
    )

    if (NOT "${ext_result}" STREQUAL "0")
        message(SEND_ERROR "Could not build ${dep}: ${ext_result}")
        return()
    endif()

    # Create a script that defines update and reinstall targets for this dep
    configure_file(
        "${templates}/DepCustomTargets.cmake.in"
        "${external_root}/targets/update_reinstall_${dep}.cmake"
        @ONLY
    )

endfunction()
