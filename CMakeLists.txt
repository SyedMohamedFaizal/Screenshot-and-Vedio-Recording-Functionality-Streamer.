cmake_minimum_required(VERSION 3.19)

project(stream LANGUAGES CXX)

# 👉 Point to your OpenCV install
set(OpenCV_DIR
    "C:/Users/Faiza/Downloads/build/install"
)

find_package(OpenCV REQUIRED)
#find_package(PkgConfig REQUIRED)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Widgets Quick)
find_package(Qt6 REQUIRED COMPONENTS Core)
#pkg_check_modules(GST REQUIRED
 #gstreamer-1.0
 #   gstreamer-video-1.0
 #   gstreamer-audio-1.0
 #   gstreamer-app-1.0
#)

qt_standard_project_setup()

qt_add_executable(stream
    WIN32 MACOSX_BUNDLE
    main.cpp


)

qt_add_qml_module(stream
    URI stream
    VERSION 1.0
    QML_FILES
    Main.qml
    SOURCES videostreamer.h videostreamer.cpp
    SOURCES opencvimageprovider.h opencvimageprovider.cpp
)
target_link_libraries(stream
    PRIVATE
        Qt::Core
        Qt::Widgets
        Qt::Quick
        #${OpenCV_LIBS}
        opencv_core
        opencv_imgproc
        opencv_videoio
        opencv_imgcodecs
)
target_link_libraries(stream PRIVATE Qt6::Core)

if(WIN32)
    # 1. Define the OpenCV Binary Path
    # Since you already set OpenCV_DIR, we point to the 'bin' folder inside it
    #set(OPENCV_BIN_DIR "${OpenCV_DIR}/x64/vc17/bin") # Adjust 'vc16' if using a different VS version

    # 2. Automated Copy: Post-Build
    # This copies the OpenCV DLLs (like opencv_world.dll) to your EXE folder
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_RUNTIME_DLLS:${PROJECT_NAME}>
        $<TARGET_FILE_DIR:${PROJECT_NAME}>
        COMMAND_EXPAND_LISTS
        COMMENT "Copying only required runtime DLLs..."
    )


endif()


include(GNUInstallDirs)

install(TARGETS stream
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
