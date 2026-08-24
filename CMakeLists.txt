cmake_minimum_required(VERSION 3.10)

project(macesque-taskmanager)

set(PROJECT_VERSION "0.9.0")

set(PROJECT_DEP_VERSION "6.6.90")
set(QT_MIN_VERSION "6.10.0")
set(KF6_MIN_VERSION "6.26.0")
set(ACCOUNTSQT_DEP_VERSION "1.13")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQtDeclareLoggingCategory)
include(CheckIncludeFiles)
include(KDEClangFormat)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Quick
    QuickWidgets
    DBus
    Widgets
    Svg
    Concurrent
    Core5Compat
    ShaderTools
    Sql # kcms/recentFiles
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Config
    CoreAddons
    DBusAddons
    Declarative
    GuiAddons # KImageCache
    I18n
    KCMUtils
    KIO
    NewStuff
    Notifications
    NotifyConfig
    Package
    Svg
    WidgetsAddons
    XmlGui
)

find_package(Plasma ${PROJECT_DEP_VERSION} REQUIRED)
find_package(PlasmaActivities ${PROJECT_DEP_VERSION} REQUIRED)
find_package(PlasmaActivitiesStats ${PROJECT_DEP_VERSION} REQUIRED)

find_package(LibNotificationManager ${PROJECT_DEP_VERSION} CONFIG REQUIRED)
find_package(LibTaskManager ${PROJECT_DEP_VERSION} CONFIG REQUIRED)
find_package(KWinDBusInterface CONFIG REQUIRED)
find_package(KSysGuard CONFIG REQUIRED)
find_package(KF6KDED CONFIG REQUIRED)

add_subdirectory(applets)
