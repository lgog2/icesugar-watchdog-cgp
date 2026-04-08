// asynchroniczne ziarno
// y0 = x1 or (x2 & ~x0)  
// y1 = ~x0
// y2 = x0 and ~x1



// synchroniczny wrapper (12MHz t=83.3 ns )
module watchdog_wrapper (
    input clk,
    input rst,
    input  [2:0] x_pins, //sygnaly z zewnatrz (asynchroniczne)
    output [3:0] y_pins //sygnaly na zewnatrz (synchroniczne) 
);

    // x_pins[0] : stan kondensatora 60s
    // x_pins[1] : stan kondensatora 5s
    // x_pins[2] : linia TX UART z NanoPi 
    
    // SYNCHRONIZACJA WEJSC ANALOGOWYCH Z KONDENSATOROW
    reg [1:0] sync_x0;
    reg [1:0] sync_x1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_x0 <= 2'b00;
            sync_x1 <= 2'b00;
        end else begin
            // definiuje strukture zizyczna wyjscie z sync_x0[0] podpiete do wejscia sync_x0[1]
            // w kazdym takcie sync_x0[1] dostaje ustabilizowany sygnal
            sync_x0 <= {sync_x0[0], x_pins[0]}; 
            sync_x1 <= {sync_x1[0], x_pins[1]};
        end
    end
    
    
    //DETEKCJA ZBOCZA OPADAJACEGO NA  UART
    reg [1:0] uart_sync;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // w stanie resetu zakladamy linie UART w stanie Idle (High)
            uart_sync <= 2'b11;
        end else begin
            // oversampling: przesuwanie stanow w takt zegara 12 MHz
            uart_sync <= {uart_sync[0], x_pins[2]};
        end
    end
    // przyjmuje stan 1 na 1 takt zegara kiedy poprzedni stan UART byl 1 a obeny to 0
    wire uart_edge_pulse = (uart_sync == 2'b10);
    
    
    // ASYNCHRONICZNY RDZEN LOGICZNY
    wire [2:0] core_x;
    wire [2:0] core_y; 
    
    // przekazanie ustabilizowanych stanow kondensatorow (przeszly przez dwa przerzutniki D)
    assign core_x[0] = sync_x0[1];
    assign core_x[1] = sync_x1[1];
    // przekazanie flagi detekcji spadku naiecia na UART
    assign core_x[2] = uart_edge_pulse;

    // inicjalizacja  cpg_core wewnatrz wrappera
    cgp_core core_inst (
        .x(core_x),
        .y(core_y)
    );
    
    // WYDLUZANIE IMPULSOW WYJSCIOWYCH (dodanie 4.2 ms)

    reg [15:0] pulse_timer [0:2]; //3 liczniki 
    reg [2:0]  out_reg; //3 rejestry wyjsciowe
    integer i;
    
    // synchroniczny filtr zegarowy - dodje 4.2 ms do dlugosci kazdej zarejestrowanej 1 na wejsciach
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 3; i = i + 1) begin
                pulse_timer[i] <= 0;
                out_reg[i]     <= 0; //0 na wszystkich wyjsciach
            end
        end else begin
            for (i = 0; i < 3; i = i + 1) begin
                if (core_y[i] == 1'b1) begin
                    pulse_timer[i] <= 16'd50000; //50000 x 83.3 ns = 4.2 ms 
                    out_reg[i]     <= 1'b1;
                end else if (pulse_timer[i] > 0) begin
                    pulse_timer[i] <= pulse_timer[i] - 1;
                    out_reg[i]     <= 1'b1;
                end else begin
                    out_reg[i]     <= 1'b0;
                end
            end
        end
    end

    assign y_pins = {out_reg[2], out_reg};
    //assign y_pins[0] = out_reg[0];
    //assign y_pins[1] = out_reg[1];
    //assign y_pins[2] = out_reg[2];
    //assign y_pins[3] = out_reg[2];
    
endmodule
