// define three registers per timer - timer, cmp and prescaler registers
`define REGS_MAX_IDX             'd3
`define REG_TIMER                 2'b00
`define REG_PRESCALER             2'b01
`define REG_CMP                   2'b10

module apb_timer 
#(
	parameter APB_ADDR_WIDTH = 12  //APB slaves are 4KB by default
)
(
    input  logic                      HCLK,
    input  logic                      HRESETn,
    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic               [31:0] PWDATA,
    input  logic                      PWRITE,
    input  logic                      PSEL,
    input  logic                      PENABLE,
    output logic               [31:0] PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR,
	
	output logic				[1:0] irq_o // overflow and cmp interrupt
);

// APB register interface
logic [`REGS_MAX_IDX-1:0]       register_adr;
assign register_adr = PADDR[`REGS_MAX_IDX + 2:2];

// registers
logic [0:`REGS_MAX_IDX] [31:0]  regs_q, regs_n;
logic [31:0] cycle_counter_n, cycle_counter_q;

//irq logic
always_comb
begin
    irq_o = 2'b0;

    // overlow irq
    if (regs_q[`REG_TIMER] == 'b1)
        irq_o[0] = 1'b1;

    // compare match irq if compare reg ist set
    if (regs_q[`REG_CMP] != 'b0 && regs_q[`REG_TIMER] == regs_q[`REG_CMP])
        irq_o[1] = 1'b1;

end

// register write logic
always_comb
begin
    regs_n = regs_q;
    cycle_counter_n = cycle_counter_q + 1;

    // reset timer after cmp or overflow
    if (irq_o[1] == 1'b1)
        regs_n[`REG_TIMER] = 1'b0;
    else if(regs_q[`REG_PRESCALER] != 'b0 && (regs_q[`REG_PRESCALER] & cycle_counter_q) == 32'b0) // prescaler
        regs_n[`REG_TIMER] = regs_q[`REG_TIMER] + 1;
    else
        regs_n[`REG_TIMER] = regs_q[`REG_TIMER] + 1;

    // written from APB bus - gets priority
    if (PSEL && PENABLE && PWRITE)
    begin

        unique case (register_adr)
            `REG_TIMER:
                regs_n[`REG_TIMER] = PWDATA;

            `REG_PRESCALER:
                regs_n[`REG_PRESCALER] = PWDATA;

            `REG_CMP:
                regs_n[`REG_CMP] = PWDATA;
        endcase
    end
end

// APB register read logic
always_comb
begin
    PRDATA = 'b0;

    if (PSEL && PENABLE && !PWRITE)
    begin

        unique case (register_adr)
            `REG_TIMER:
                PRDATA = regs_q[`REG_TIMER];

            `REG_PRESCALER:
                PRDATA = regs_q[`REG_PRESCALER];

            `REG_CMP:
                PRDATA = regs_q[`REG_CMP];
        endcase

    end
end
// synchronouse part
always_ff @(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn)
    begin
        regs_q          <= '{default: 32'b0};
        cycle_counter_q <= 32'b0;
    end
    else
    begin            
        regs_q          <= regs_n;
        cycle_counter_q <= cycle_counter_n;
    end
end


endmodule