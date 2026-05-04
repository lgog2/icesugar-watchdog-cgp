Dokumentacja sprzetowa:


* **Płyta Deweloperska:** [iCESugar-Nano GitHub Repository](https://github.com/wuxx/icesugar-nano) 

* **Matryca FPGA:** [Lattice iCE40 LP/HX Family Data Sheet](https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://www.latticesemi.com/~/media/latticesemi/documents/datasheets/ice/ice40lphxfamilydatasheet.pdf&ved=2ahUKEwi3ysLlv96TAxUQR1UIHXMEJP0QFnoECBAQAQ&usg=AOvVaw0AXd6WaYQV8a_WNdYmwOb) (Układ docelowy: **iCE40LP1K-CM36**)

* **Toolchain:** Yosys / NextPNR-iCE40 (Ekosystem Project IceStorm)
___________________________________________________________________________________________________________________
SCHEMAT UKŁADU: Sprzętowy Watchdog (FPGA + RC)
<img width="1169" height="826" alt="SCHEMAT_UKŁADU" src="https://github.com/user-attachments/assets/fadaf0c7-39bd-473e-8a25-635c2086b3f7" />

___________________________________________________________________________________________________________________
Demonstracja działania: 

Film prezentuje funkcjonalny prototyp hybrydowego watchdoga. Czas odmierzany jest analogowo (ładowanie dwóch kondensatorów 100uF), a sterowanie i rozładowywanienie kondensatorów realizowane są przez asynchroniczną maszynę stanów zaimplementowaną w Verilogu na FPGA iCESugar-Nano.

**Kalibracja czasów (Wartości RC):**
* **~42 sekundy** (Czas pracy) – rezystor 600 kΩ
* **~3.7 sekundy** (Czas odcięcia zasilania) – rezystor 47 kΩ

**Sygnalizacja diagnostyczna LED (od lewej):**
1.  🔴 **Czerwona:** Odcięcie zasilania NanoPi (aktualnie odłączona)
2.  🟡 **Żółta:** Rozładowywanie kondensatora 3.7s
3.  🔵 **Niebieska:** Rozładowywanie kondensatora 42s
4.  🟢 **Zielona:** Stan kondensatora 3.7s (oczekiwanie na naładowanie
5.  🔴 **Czerwona:** Stan kondensatora 42s (oczekiwanie na naładowanie)
6.  🔵 **Niebieska:** Sygnał życia od NanoPi (zbocze opadające – symulowane wpięciem do masy)

**Środowisko testowe:**
Układ odcinający zasilanie jest wpięty w rzeczywisty zasilacz 5V. Samo NanoPi zostało na potrzeby testu zastąpione żółtą diodą LED, która gaśnie w momencie aktywacji resetu sprzętowego.

https://github.com/user-attachments/assets/d579fb45-be3b-4c47-876f-1baa7433d37b
