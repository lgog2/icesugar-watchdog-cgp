module blink (
	input clk, //12 MHz
	output led_red
);

//  2^23 / 12 000 000 = ok 0.7 
reg [23:0] counter;

initial begin
	counter =0;
end

always @(posedge clk) begin
	counter <= counter + 1;
end

assign led_red = ~counter[23];

endmodule
