此代码fork自doubango官方库。
fork此库的目的是用来编译x86_64\ARM64版本的适用于android的tinywrap库。
原代码存在的问题有
1、binding/_common/sipStack.i文件中不正确的注释。
2、需要加 -fexceptions 编译标识
3、编译产物中没有 *.so.0.0.0 文件。
添加了一个自动编译Action脚本。

修改了android_build.sh脚本，只编译x86_64和Arm64版本。

2025.06.22
