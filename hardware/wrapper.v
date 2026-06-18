// asynchroniczne ziarno
// y0 = x1 or (x2 & ~x0)  
// y1 = ~x0
// y2 = x0 and ~x1


// synchroniczny wrapper (12MHz t=83.3 ns )
module wrapper (
    input  wire clk,         // 12 MHz
    input  wire [2:0] x_pins,    // sygnaly z zewnatrz (asynchroniczne)
    output wire [2:0] y_pins,    // sygnaly na zewnatrz (synchroniczne) (bez wydluzania)
    output wire [4:0] debug_pins  // Diagnostyka (wydluzone ~20ms)
);

     // x_pins[0] : stan kondensatora 60s
    // x_pins[1] : stan kondensatora 5s
    // x_pins[2] : linia TX UART z NanoPi 
    
    // y_pins[0] : rozladuj kondensator 60s (Utrzymanie pracy NanoPi)
    // y_pins[1] : rozladuj kondensator 5s  (Przygotowanie timera resetu)
    // y_pins[2] : odcinaj zasilanie NANOPI
    
    // =======================================
    // SOFT RESET przez 32768 taktow zegara pierwszych (2.7ms)
    // =======================================
    reg [15:0] por_counter = 16'd0;
    
    wire rst = !por_counter[15]; 
    always @(posedge clk) begin
        if (rst) begin
            por_counter <= por_counter + 1'b1;
        end
    end
    // always @(posedge clk) if (rst) por_counter <= por_counter + 1'b1;

    // ==========================================
    // SYNCHRONIZACJA WEJSC ANALOGOWYCH Z KONDENSATOROW (filtr 1ms - SAFE_MODE)
    // ==========================================
    
    reg [1:0] sync_x0;
    reg [1:0] sync_x1;
    // zabezpieczenie przed metastabilnoscia - domena czasu
    always @(posedge clk) begin
        if (rst) begin
            sync_x0 <= 2'b00;
            sync_x1 <= 2'b00;
        end else begin
            //w kazdym takcie sync_x0[1] dostaje ustabilizowany sygnal
            sync_x0 <= {sync_x0[0], x_pins[0]}; 
            sync_x1 <= {sync_x1[0], x_pins[1]};
        end
    end
    
`ifdef SAFE_MODE

    reg clean_x0, clean_x1;
    reg [13:0] timer_0, timer_1;
    
    always @(posedge clk) begin
    	if (rst) begin
            clean_x0 <= 1'b0;
            clean_x1 <= 1'b0;
            timer_0  <= 14'd0;
            timer_1  <= 14'd0;
        end else begin
            // Filtracja K_60s
            if (sync_x0[1] == clean_x0) begin
                timer_0 <= 14'd0;
            end else begin
                timer_0 <= timer_0 + 1'b1;
                // rejsetracja dopiero sygnalu trwajacego 1ms
                if (timer_0 == 14'd12000) begin // 1ms
                    clean_x0 <= sync_x0[1]; 
                    timer_0 <= 14'd0; 
                end
            end
            
            // Filtracja K_5s
            if (sync_x1[1] == clean_x1) begin
                timer_1 <= 14'd0;
            end else begin
                timer_1 <= timer_1 + 1'b1;
                if (timer_1 == 14'd12000) begin
                    clean_x1 <= sync_x1[1]; 
                    timer_1 <= 14'd0; 
                end
            end
        end
    end
    
    wire final_x0 = clean_x0;
    wire final_x1 = clean_x1;
    
`else
    
    wire final_x0 = sync_x0[1];
    wire final_x1 = sync_x1[1];

`endif


    // ==========================================
    // DETEKCJA ZBOCZA OPADAJACEGO UART i wydluzenie do 30ms(3RC dla R=100ohm i C=100uF)
    // ==========================================
    reg [2:0] uart_sync;
    reg [18:0] uart_stretch_timer = 0;
    // oversampling: przesuwanie stanow w takt zegara 12 MHz
    always @(posedge clk) begin
        if (rst) begin
            uart_stretch_timer <= 0;
            // w stanie resetu linia UART w stanie Idle (High)
            uart_sync <= 3'b111;
        end else begin
            // Bit [0] - stan lini UART (narażony na metastabilność)
            // Bit [1] - sygnał ustabilizowany / obecny stabilny stan
            // Bit [2] - historyczny stabilny stan (poprzedni takt)
            uart_sync <= {uart_sync[1:0], x_pins[2]};
            if (uart_sync[2:1] == 2'b10) begin
            	uart_stretch_timer <= 19'd360000; // ~30 ms
       	    end else if (uart_stretch_timer > 0) begin
                uart_stretch_timer <= uart_stretch_timer - 1'b1;
            end
        end
    end
    
    wire uart_stable_long = (uart_stretch_timer > 0);

    // ==========================================
    // ASYNCHRONICZNY RDZEN LOGICZNY
    // ==========================================
    
    wire [2:0] core_x = {uart_stable_long, final_x1, final_x0};
    wire [2:0] core_y;
    
    // inicjalizacja  cpg_core wewnatrz wrappera
    cgp_core core_inst (
        .x(core_x), 
        .y(core_y)
    );

    // ==========================================
    // SYGNALY WYJSCIOWE (BEZ WYDLUZANIA)
    // ==========================================
    // w fazie resetu kondensatory rozladowywane napiecie do Nanopi nieodciete
    assign y_pins = rst ? 3'b011 : core_y;

    // ==========================================
    // DEBUGOWANIE - sygnaly wydluzone do 20ms
    // ==========================================
    reg [17:0] led_timers [0:1];
    integer i;

    always @(posedge clk) begin
        for (i = 0; i < 2; i = i + 1) begin
            if (core_y[i]) led_timers[i] <= 18'd240000; // ~20ms
            else if (led_timers[i] > 0) led_timers[i] <= led_timers[i] - 1;
        end
    end

    assign debug_pins[0] = uart_stable_long;    // Out:30ms przy zboczu opadajacym UART
    assign debug_pins[1] = final_x0;            // In:stan k 60s(z filtrem 1ms albo bez)
    assign debug_pins[2] = final_x1;            // In:stan k 5s(z filtrem 1ms albo bez)
    assign debug_pins[3] = (led_timers[0] > 0); // Out:rozladowywanie k 60s
    assign debug_pins[4] = (led_timers[1] > 0); // Out:rozladowywanie k 5 sek
    
endmodule
