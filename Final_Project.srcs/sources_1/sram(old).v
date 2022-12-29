//
// This module show you how to infer an initialized SRAM block
// in your circuit using the standard Verilog code.  The initial
// values of the SRAM cells is defined in the text file "image.dat"
// Each line defines a cell value. The number of data in image.dat
// must match the size of the sram block exactly.

module sram
#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 19, RAM_SIZE = 65536)
 (input clk, input we, input en,
  input  [ADDR_WIDTH-1 : 0] addr,
  input  [DATA_WIDTH-1 : 0] data_i,
  output reg [DATA_WIDTH-1 : 0] data_o);

// Declareation of the memory cells
// (* ram_style = "block" *) reg [DATA_WIDTH-1 : 0] RAM [RAM_SIZE - 1:0];

integer idx;

// ------------------------------------
// SRAM cell initialization
// ------------------------------------
// Initialize the sram cells with the values defined in "image.dat."
//initial begin
//    $readmemh("images.mem", RAM);
//end

// ------------------------------------
// SRAM read operation
// ------------------------------------
always@(posedge clk)
begin
  if (en & we)
    data_o <= data_i;
  else if(addr % 2)
    data_o <= 0;
   else
    data_o <= 12'hFFF;
end

// ------------------------------------
// SRAM write operation
// ------------------------------------
// always@(posedge clk)
// begin
//   if (en & we)
//     RAM[addr] <= data_i;
// end

endmodule


module sram_background
 (input clk, input we, input en,
  input  is_black,
  input color_change,
  input  [12-1 : 0] data_i,
  output reg [12-1 : 0] data_o,
  input is_food,
  input is_snake,
  input is_snake_head, 
  input is_bumped,
  input is_block, input block_transparent);

integer idx;

always@(posedge clk)
begin
  if (en & we) begin
      data_o <= data_i;
  end
  else if(is_black) begin
      data_o <= 12'h0;
  end
  else if(color_change) begin
      if (is_snake_head) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if (is_snake) begin
        if (is_bumped) data_o <= 12'hF0F;
        else data_o <= 12'h080;
      end
      else if(is_food) begin 
          data_o <= 12'h123;
      end
      else if(is_block && ~block_transparent) begin
          data_o <= 12'h666;
      end
      else begin
          data_o <= 12'hBEF;
      end
  end
  else  begin
      if (is_snake_head) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if (is_snake) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if(is_food) begin
          data_o <= 12'h123;
      end
      else if(is_block && ~block_transparent) begin
          data_o <= 12'h666;
      end
      else begin
          data_o <= 12'hFEB;
      end
  end
end

endmodule
