![alt tag](https://dl.dropboxusercontent.com/u/11700363/screen.png)

The screen below is from Mindy, a FlasCard application that uses WhiteStag Engine. Mindy is similar to Anki, but it has some enhancement and it is designed for programmers and foreign-language-learners.
![alt tag](https://dl.dropboxusercontent.com/u/11700363/2014-04-10%2011_27_54-SDL_app.png)

A Project a jelenlegi Nimrod compiler-rel nem folytatható: Több olyan idegesítő és nem determinisztikus hiba is előjött, amiket nem engedhetek meg egy komolyann projekt közepén.
Most egy leírás következik egy-két súlyosabb hibáról, hogy a jővőben majd ezeket tesztelve megbizonyodhassak róla, a compiler javítva lett.

Ha a mindy/types.nim-ben a TQuestion.id TOption[int64] típusú, és beimportálom ezt a fájlt (meg asszem a db.nim-et) a mindy.nim-be, akkor a program elhasal az első addView metódusban. Olyan, mintha az addView-nak átadott child paraméter nem egy POption[PView], hanem az előbb definiált TOption[int64] lenne.

view.nim:249. Valamiért azt mondja a self.pExecuting-ra, hogy nem létező field...