module decode #(parameter xlen = 32)                 // Instruction length, e.g., 32-bit or 64-bit
(
    input  wire                   clk,                // Clock signal
    input  wire                   reset_n,            
    input  wire [xlen-1:0]        current_instruction, // Instruction from Fetch unit
    input  wire [xlen-1:0]        current_pc,          // receive from Fetch unit

    output reg [3:0]              operation,          //  sent to EX
    output reg [$clog2(xlen)-1:0] src1_addr,          // sent to the register file
    output reg [$clog2(xlen)-1:0] src2_addr,          // sent to the register file
    output reg [$clog2(xlen)-1:0] dest_addr,          // sent to the register file
    output reg [xlen-1:0]         imm,                // Immediate value sent to EX
    output reg                    use_imm,            // Flag to indicate usage of immediate
    output reg                    is_load_store       // Sent to the memory and writeback unit
);

    // intermediate signals for decoding purposes
    reg [6:0]  opcode;       // used for operation decoding
    reg [2:0]  func3;        // 3-bit function for certain operations
    reg [6:0]  func7;        // 7-bit function for certain operations

    always @ (posedge clk or negedge reset_n) begin
        if (reset_n) begin
            opcode    <= 7'b0;
            func3     <= 3'b0;
            func7     <= 7'b0;
            imm       <= {xlen{1'b0}};
            operation <= 4'b0000;
            src1_addr <= 0;
            src2_addr <= 0;
            dest_addr <= 0;
            use_imm   <= 0;
            is_load_store <= 0;
        end else begin
            // Extract common fields
            opcode <= current_instruction[6:0];       // Bits [6:0] are opcode
            func3  <= current_instruction[14:12];     // Bits [14:12] are func3
            func7  <= current_instruction[31:25];     // Bits [31:25] are func7 (for R-type)

            // Set default values
            src1_addr   <= current_instruction[19:15]; // Register source 1 address
            src2_addr   <= current_instruction[24:20]; // Register source 2 address (for R-type)
            dest_addr   <= current_instruction[11:7];  // Destination register address
            use_imm     <= 0;  // Default: Don't use immediate
            is_load_store <= 0; // Default: Not load/store operation

            // Opcode-based decoding
            case (opcode)
                // R-Type Instructions
                7'b0110011: begin
                    use_imm <= 0; // R-type doesn't use immediate
                    case (func3)
                        3'b000: operation <= (func7 == 7'b0000000) ? 4'b0000 : 4'b0001; // ADD/SUB
                        3'b001: operation <= 4'b0010; // SLL
                        3'b100: operation <= 4'b0101; // XOR
                        3'b101: operation <= (func7 == 7'b0000000) ? 4'b0011 : 4'b0100; // SRL/SRA
                        3'b110: operation <= 4'b0111; // OR
                        3'b111: operation <= 4'b0110; // AND
                        default: operation <= 4'bxxxx; // Undefined operation
                    endcase
                end

                // I-Type Arithmetic Instructions
                7'b0010011: begin
                    use_imm <= 1; // I-type uses immediate
                    imm <= {{20{current_instruction[31]}}, current_instruction[31:20]}; // Sign-extended immediate
                    case (func3)
                        3'b000: operation <= 4'b0000; // ADDI
                        3'b100: operation <= 4'b0101; // XORI
                        3'b110: operation <= 4'b0111; // ORI
                        3'b111: operation <= 4'b0110; // ANDI
                        default: operation <= 4'bxxxx; // Undefined operation
                    endcase
                end

                // Load Instructions (I-Type)
                7'b0000011: begin
                    use_imm <= 1; // Load uses immediate
                    imm <= {{20{current_instruction[31]}}, current_instruction[31:20]}; // Sign-extended immediate
                    is_load_store <= 1; // This is a load instruction
                    case (func3)
                        3'b010: operation <= 4'b1000; // LW (Load Word)
                        default: operation <= 4'bxxxx; // Undefined operation
                    endcase
                end

                // Store Instructions (S-Type)
                7'b0100011: begin
                    use_imm <= 1; // Store uses immediate
                    imm <= {{20{current_instruction[31]}}, current_instruction[31:25], current_instruction[11:7]}; // Sign-extended immediate (S-type)
                    is_load_store <= 1; // This is a store instruction
                    case (func3)
                        3'b010: operation <= 4'b1001; // SW (Store Word)
                        default: operation <= 4'bxxxx; // Undefined operation
                    endcase
                end

                default: begin
                    // Default case for unknown opcodes
                    operation <= 4'bxxxx;
                    use_imm <= 0;
                    is_load_store <= 0;
                end
            endcase
        end
    end

endmodule
