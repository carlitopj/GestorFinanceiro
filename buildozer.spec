[app]

title = Gestor Financeiro
package.name = gestorfinanceiro
package.domain = org.lidiane

source.dir = .
source.include_exts = py,png,jpg,kv,atlas,db

version = 1.0

requirements = python3,kivy==2.3.0,kivymd==1.2.0,sqlite3,pandas,matplotlib,plyer,openpyxl,pillow,certifi

orientation = portrait
fullscreen = 0

icon.filename = %(source.dir)s/icon.png

android.permissions = READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE,MANAGE_EXTERNAL_STORAGE

android.api = 33
android.build_tools = 33.0.2
android.minapi = 24
android.ndk = 25b
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True

# Necessário para o seletor de arquivos (plyer / SAF) funcionar corretamente
android.add_compile_options = sourceCompatibility = JavaVersion.VERSION_1_8, targetCompatibility = JavaVersion.VERSION_1_8

[buildozer]
log_level = 2
warn_on_root = 1

