project(foo)
file(GLOB SRCS *.h *.c *.cpp)
add_library(${PROJECT_NAME} ${SRCS})
target_link_libraries(${PROJECT_NAME} core)
target_include_directories(${PROJECT_NAME} PUBLIC .)
