# Pojednostavljena interaktivna simulacija protuoklopnog vođenog raketnog sustava (Godot)

Ovaj projekt predstavlja interaktivnu 3D simulaciju vođenog protuoklopnog raketnog sustava izrađenu u **Godot Engineu**.  
Cilj je prikazati fizikalno i dinamičko ponašanje rakete tijekom leta te način navođenja u različitim atmosferskim i okolišnim uvjetima.

---

## Opis projekta

Simulacija omogućuje ispaljivanje i navođenje rakete u virtualnom 3D okruženju.  
Nakon inicijalne faze leta, korisnik preuzima kontrolu nad raketom i upravlja njezinim smjerom pomoću **joysticka** ili miša (emulacija joysticka).  
Postoji mogućnost proširenja na **automatsko navođenje** radi usporedbe različitih sustava kontrole.

Okruženje uključuje jednostavne 3D terene i uvjete poput **vjetra, turbulencije, dana/noći**, te prikaz kroz **optičku, termalnu, IR i zvučnu kameru**.  
Korisnik može birati pogled iz **prvog** ili **trećeg lica**.

---

## Fizikalni model

Raketa je modelirana s osnovnim fizikalnim parametrima — **masa, potisak, otpor zraka, gravitacija i momenti**.  
Gibanje se računa pomoću vlastitog numeričkog modela u skriptama (ručni update položaja i rotacije), što omogućuje realističniju kontrolu vanjskih utjecaja poput vjetra ili turbulencije.  
Time se postiže vjerodostojno, ali računski učinkovito ponašanje rakete u letu.

---

## Sustav navođenja i prikaz

Sustav navođenja temelji se na ručnom vođenju (MCLOS) putem korisničkog unosa, dok se planira i implementacija **poluautomatskog SACLOS** načina.  
Tijekom leta, **HUD (Head-Up Display)** prikazuje ključne parametre: visinu, brzinu, vektor vjetra, smjer leta i osnovne statusne indikatore.  
U vizualnom smislu, naglasak je na funkcionalnoj simulaciji navođenja, a ne na destruktivnim efektima.

---

## Struktura repozitorija

docs/ → Tehnička dokumentacija, dijagrami i izvještaji
implementation/ → Godot projekt, skripte i 3D modeli simulacije
releases/ → Izvozne (buildane) verzije simulacije za krajnje korisnike
assets/ → Modeli, teksture i pomoćni materijali

---

## Tehnologije

- **Godot Engine 4.5** — izrada i izvođenje 3D simulacije  
- **GDScript (C# po potrebi)** — implementacija fizikalnih i upravljačkih modela  
- **LaTeX** — izrada dokumentacije  
- **Git / GitHub** — verzioniranje i kolaboracija unutar tima

---

## Cilj projekta

Projekt ima za cilj razviti obrazovnu i tehnički uvjerljivu simulaciju koja prikazuje osnovne principe vođenja i dinamike leta protuoklopne rakete.  
Naglasak je na **realističnom modeliranju fizike i upravljanju**, a ne na kompleksnoj grafici, čime se omogućuje jasno razumijevanje koncepta i razvoj budućih proširenja.

---

Projekt je izrađen u sklopu kolegija **Interaktivni simulacijski sustavi**  
na **Fakultetu elektrotehnike i računarstva, Sveučilište u Zagrebu**.
