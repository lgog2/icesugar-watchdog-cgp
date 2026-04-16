module top (
    input  wire clk,         // zagar systemowy 12 MHz 
    input  wire ext_pin_rst, // asynchroniczny reset (Pin B3 PMOD2)
    input  wire [2:0] x_pins, // wejcia z kondensatowow i  UART NanoPi
    output wire [2:0] y_pins,  // wyjscia 
    output wire [4:0] debug_pins  // wyjscia diagnostyczne
);
    // separacja na przyszlosc gdyby np potrzebny by resset stanem niskim
    wire sys_rst = ext_pin_rst;

    watchdog_wrapper wrapper_inst (
        .clk(clk),
        .rst(sys_rst),
        .x_pins(x_pins),
        .y_pins(y_pins),
        .debug_pins(debug_pins)
    );
    


     
    // test -wymuszone 1 ma wszytkich wyjsciach (PMOD3)
    //assign y_pins[0] = 1'b1; // C6 
    //assign y_pins[1] = 1'b1; // E3 
    //assign y_pins[2] = 1'b1; // C2 
    //assign y_pins[3] = 1'b1; // A1 



endmodule

