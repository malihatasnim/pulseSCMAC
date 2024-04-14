module LFSR_2BitStream_sequential (input clk, 
							   input rst, 
							   output wire [1:0]o2_stream);
  reg [6:0] op;
  assign o2_stream=op[4]?(op[5]?(op[6]?2'b11:2'b10):2'b01):2'b00;
  always@(posedge clk) begin
    if(rst) op <= 7'd35;
    else op <= {op[5:0],~(op[2]^op[0])}; 
  end 
endmodule

module up_counter #parameter (NBITS=8)(input wire rst, 
									   input wire clk, 
									   input wire en,
									   
									   output reg [NBITS-1:0]COUNT);
	reg [NBITS-1:0]c;
	always @(rst, en, COUNT) begin
		case (rst, en)
			2'b00: c=COUNT;
			2'b10: c=0;
			2'b01: c=COUNT+1;
			default: c=0;
		endcase
	end
	
	always @(posedge clk) COUNT=c;
	
endmodule



module sc_mult_sequential #(parameter NBITS=8)(input [NBITS-1:0]X,
											   input [NBITS-1:0]Y, 
										  	   input [NBITS-1:0]COUNT,
										  	   output reg mult_stream);
	wire c;
	assign c=Y<COUNT?1'b1:1'b0;
	assign st_stream=  COUNT[0]?
					  (COUNT[1]?
					  (COUNT[2]?
					  (COUNT[3]?
					  (COUNT[4]?
					  (COUNT[5]?
					  (COUNT[6]?
					  (COUNT[7]?1'b0:X[0]):X[1]):X[2]):X[3]):X[4]):X[5]):X[6]):X[7];
	always @(st_stream,c) begin
		mult_stream=c?st_stream:1'b0;
	end
endmodule

module sc_add_sequential #(parameter NBITS=8)(input wire m1_stream, 
											  input wire m2_stream, 
											  input wire m3_stream, 
											  input wire m4_stream,
											  input wire [1:0] selector_stream,
										  	  output reg add_stream);
	always @(*) begin
		case (selector_stream)
			2'b00: add_stream<=m1_stream;
			2'b01: add_stream<=m2_stream;
			2'b10: add_stream<=m3_stream;
			2'b11: add_stream<=m3_stream;
		endcase
	end

endmodule


module sc_mac_sequential #(parameter NBITS=8, FIRLOG=8)(input wire [NBITS-1:0] X1, 
													    input wire [NBITS-1:0] Y1,
													   input wire [NBITS-1:0] X2, 
													   input wire [NBITS-1:0] Y2, 
													   input wire [NBITS-1:0] X3, 
													   input wire [NBITS-1:0] Y3,
													   input wire [NBITS-1:0] X4, 
													   input wire [NBITS-1:0] Y4, 
													   input wire clk,
													   output reg [NBITS+1:0]mac_out,
													   input rst,
													   input start_,
													   input bin_out,
													   input [FIRLOG-1:0]LFIR);
	parameter SCBITS=(1<<NBITS)-1;
	reg [FIRLOG-1:0]l;
	
	parameter IDLE=3'b000;
	parameter MADD_start=3'b001;
	parameter MADD=3'b100;
	parameter MADD_done=3'b101;
	parameter MAC_done=3'b111;
	parameter bin_out=3'b110;
	
	reg [2:0]n_state;
	reg[2:0]c_state;
	
	wire [NBITS-1:0]COUNT;
	reg [NBITS-1:0]mac_bin;
	reg [NBITS-1:0]mb;
	
	wire mult1_sream, mult2_stream, mult3_stream, mult4_stream, add4_stream;
	
	
	wire madd_stream, acc_stream;
	reg rst_lfsr, rst_counter, rst_mac;
	reg mac_en, en_counter;
	wire [1:0]selector_stream;
	
	
	
	LFSR_2BitStream_sequential ulfsr2(.clk(clk), .rst(rst_lfsr), .o2_stream(selector2_stream));
	
	up_counter ucup(.clk(clk), .COUNT(COUNT), .rst(rst_counter), .en(en_counter));
	
	
	sc_mult_sequential uscms1(.X(X1), 
							  .Y(Y1),
					   		  .COUNT(COUNT),
					   		  .mult_stream(mult1_stream));
	sc_mult_sequential uscms2(.X(X2), 
							  .Y(Y2),
					   		  .COUNT(COUNT),
					   		  .mult_stream(mult2_stream));
	sc_mult_sequential uscms3(.X(X3), 
							  .Y(Y3),
					   		  .COUNT(COUNT),
					   		  .mult_stream(mult3_stream));				   		  
	sc_mult_sequential uscms4(.X(X4), 
							  .Y(Y4),
					   		  .COUNT(COUNT),
					   		  .mult_stream(mult4_stream));
					   		  
	sc_add_sequential uscas(.m1_stream(mult1_stream), 
							.m2_stream(mult2_stream), 
							.m3_stream(mult3_stream), 
							.m4_stream(mult4_stream),
							.selector_stream(selector2),
							.add_stream(add4_stream));
					   		  
	
	always @(n_state) begin
		case(n_state)
			IDLE:begin
					rst_lfsr<=1'b1;
					rst_counter<=1'b1;
					rst_mac<=1'b1;
					en_counter<=1'b0;
					mac_en=1'b0;
					l<=0;
					c_state<=start_?MADD:IDLE;
					
				 end
				 
			MADD:begin
					rst_lfsr<=1'b0;
					rst_counter<=1'b0;
					rst_mac<=1'b0;
					en_counter<=1'b1;
					mac_en=1'b1;
					c_state<=(COUNT==SCBITS)?((l==LFIR)?MAC_done:MADD_done):MADD;
				end
			MADD_done:begin
					rst_lfsr<=1'b0;
					rst_counter<=1'b0;
					rst_mac<=1'b0;
					en_counter<=1'b1;
					mac_en=1'b1;
					c_state<=(l==LFIR)?MAC_done:MADD_done;
				end 
			MAC_done:begin
					rst_lfsr<=1'b0;
					rst_counter<=1'b0;
					rst_mac<=1'b0;
					en_counter<=1'b0;
					mac_en=1'b0;
					c_state<=IDLE;
				end
		endcase
	end
		
	always @(*)begin
		case (mac_en, rst_mac) 
			2b'00: mb<=mac_bin;
			2b'01: mb<=0;
			2b'10: mb<=mac_bin+add_stream;
			default: mb=0;
		endcase
	end
	
	always (@ posedge clk) begin
		n_state<=c_state;
		mac_bin=mb;		
	end
	assign mac_out[NBITS+1:0]={bin_out?mac_bin:0, 2'b0};
endmodule

	
	

