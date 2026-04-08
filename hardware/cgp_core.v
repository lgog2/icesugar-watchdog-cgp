
module cgp_core (
    input  wire [2:0] x,
    output wire [2:0] y
);
    // --------------------------------------------------------
    // DEFINICJA WEJSC (Dostarczonych przez Wrapper):
    // x[0] : kondensator 60s (1 = pelny, NanoPi zawieszone)
    // x[1] : kondensator 5s  (1 = pelny, reset sprzętowy zakonczony)
    // x[2] : sygnal zycia NANOPI   (1 = przetworzony przez wrapper spadek napiecia na UART)
    // --------------------------------------------------------
    // DEFINICJA WYJSC (Przekazywanych do Wrappera):
    // y[0] : rozladuj kondensator 60s (Utrzymanie pracy NanoPi)
    // y[1] : rozladuj kondensator 5s  (Przygotowanie timera resetu)
    // y[2] : laduj kondensator 5s     (odlicznie odciecia zasilania NANOPI)
    // --------------------------------------------------------

    
    // sygnal zycia (x[2]) resetuje 60s tylko wtedy, gdy 60s nie uplynelo (~x[0])
    // w przeciwnym razie czeka na koniec resetu (x[1]).
    assign y[0] = (x[2] & ~x[0]) | x[1]; 
    
    // utrzymuje kondensator 5s pusty jezeli 60sek nie uplynelo.
    assign y[1] = ~x[0]; 
    
    // uruchomienie odciecia zasilania jezeli 60s minelo ale 5s jeszcze nie uplynelo(wiec trwa5s)
    assign y[2] = x[0] & ~x[1]; 

endmodule
