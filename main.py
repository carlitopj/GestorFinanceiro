from kivymd.app import MDApp
from kivy.lang import Builder

class GestorFinanceiroApp(MDApp):
    def build(self):
        return Builder.load_file("gestor.kv")

if __name__ == "__main__":
    GestorFinanceiroApp().run()
