//////////////////////////////////////////////////////////////////////////////
//  Copyright (C) by RivieraWaves.
//  This module is a confidential and proprietary property of RivieraWaves
//  and a possession or use of this module requires written permission
//  from RivieraWaves.
//----------------------------------------------------------------------------
// $Author: jvanthou $
// Company          : RivieraWaves
//----------------------------------------------------------------------------
// $Revision: 7797 $
// $Date: 2013-05-13 09:54:53 +0200 (Mon, 13 May 2013) $
// ---------------------------------------------------------------------------
// Dependencies     : None
// Description      : upstream bus interface
// Simulation Notes : 
// Synthesis Notes  :
// Application Note :
// Simulator        :
// Parameters       :
// Terms & concepts :
// Bugs             :
// Open issues and future enhancements :
// References       :
// Revision History :
// ---------------------------------------------------------------------------
//
// $HeadURL: https://svn.frso.rivierawaves.com/svn/rw_wlan_nx/trunk/Projects/WLAN_NX_REF_IP/HW/SB/rw_dini_dma/verilog/rtl/upstream_ahbif.v $
//
//////////////////////////////////////////////////////////////////////////////

`define RW_SIMU
module upstream_ahbif
(
  /*****************************************************************************
  * System
  *****************************************************************************/
  input  wire           clk,
  input  wire           rst_n,

  /*****************************************************************************
  * control/state
  *****************************************************************************/
  input  wire           start,
  input  wire           pause,
  output reg            done,

  /*****************************************************************************
  * Static parameters
  *****************************************************************************/
  input  wire [31:0]    src_addr,
  input  wire [15:0]    src_length,
 
  /*****************************************************************************
  * AHB interface
  *****************************************************************************/
  output reg  [31:0]    haddr,
  output reg  [ 1:0]    htrans,
  input  wire [31:0]    hrdata,
  input  wire           hready,

  /*****************************************************************************
  * aligner interface
  *****************************************************************************/
  output reg  [63:0]    data,
  output reg            data_en,
  output reg            data_last
);

  /*****************************************************************************
  * declarations
  *****************************************************************************/
  localparam   S_IDLE =3'b000,
               S_A    =3'b001,
               S_AD   =3'b010,
               S_D    =3'b011,
               S_PAUSE=3'b100;

  reg  [ 2:0]  state;
  reg  [12:0]  count;
  reg  [ 0:0]  nread;
  
  wire [12:0]  new_count;
  wire [31:0]  new_addr;
  
  wire [ 2:0]  reliquat;
  wire [15:0]  nbr_qwordsx8;

  /*****************************************************************************
  * FSM
  *****************************************************************************/
  assign new_count    = count - 1;
  assign new_addr     = {haddr[31:2] + 1,2'b0};
  
  assign reliquat     = src_addr[2:0] + src_length[2:0];
  assign nbr_qwordsx8 = src_length[15:0]      +
                        {13'b0,src_addr[2:0]} +
                        {12'b0,|reliquat,3'b0};

  always @(posedge clk,negedge rst_n)
  begin
  
    if(rst_n==1'b0)
    begin
    
      haddr       <= 32'b0;
      htrans      <= 2'b0;
      
      data        <= 64'b0;
      data_en     <= 1'b0;
      data_last   <= 1'b0;
    
      count       <= 16'b0;
      done        <= 1'b0;
      nread       <= 1'b0;
      
      state       <= S_IDLE;
      
    end
    else
    begin

      data_en   <= 1'b0;
      data_last <= 1'b0;
    
      case(state)
      
        /***********************************************************************
        * IDLE
        ***********************************************************************/
        default:
        begin
        
          data      <= 64'b0;
          nread     <= 1'b0;
                    
          if(~done & start)
          begin
          
            /* display first bus address */
            
            count    <= {nbr_qwordsx8[15:3],1'b0};
          
            haddr    <= {src_addr[31:3],3'b0};
            htrans   <= 2'b10;
           
            state    <= S_A;
            
          end
          else if(done & ~start)
          begin
          
            done <= 1'b0;
          
          end
        
        end
        
        /***********************************************************************
        * A
        ***********************************************************************/
        S_A:
        begin
        
          if(hready)
          begin
          
            count <= new_count;
            
            if(count==1)
            begin
            
              htrans <= 2'b0;
              state  <= S_D;
            
            end
            else
            begin
            
              if(pause)
              begin
              
                htrans  <= 1'b0;
                state   <= S_D;
              
              end  
              else
              begin
              
                haddr   <= new_addr;
                htrans  <= 2'b11;
                state   <= S_AD; 
            
              end
            
            end
            
          end
        
        end
        
        /***********************************************************************
        * D
        ***********************************************************************/
        S_D:
        begin
        
          if(hready)
          begin
            nread     <= nread + 1;
          
            if(nread == 1'd1)
            begin
              data[63:32] <= hrdata;
              data_en     <= 1'b1;
              nread       <= 1'd0;
            end
            else
            begin
              data[31:0]  <= hrdata;
              data_en     <= 1'b0;
            end
            
            if(count==0)
            begin
            
              data_last <= 1'b1;
              done      <= 1'b1;
              state     <= S_IDLE;
              
            end
            else
            begin
            
              if(pause)
              begin
              
                state <= S_PAUSE;
              
              end
              else
              begin
              
                haddr  <= new_addr;
                htrans <= 2'b11;
                state  <= S_A;
                
              end
            
            end
            
          end
        
        end
        
        /***********************************************************************
        * AD
        ***********************************************************************/
        S_AD:
        begin
        
          if(hready)
          begin
          
            nread     <= nread + 1;
            if(nread == 1'd1)
            begin
              data[63:32] <= hrdata;
              data_en     <= 1'b1;
              nread       <= 1'd0;
            end
            else
            begin
              data[31:0]  <= hrdata;
              data_en     <= 1'b0;
            end
           
            count   <= new_count;

            if(count==0)
            begin
            
              data_last <= 1'b1;
              done      <= 1'b1;
              state     <= S_IDLE;
              
            end
            
            if(pause)
            begin
            
              htrans <= 1'b0;
              state  <= S_D;
              
            end
            else
            begin
            
              if(count==1)
              begin
              
                htrans <= 1'b0;
                state  <= S_D;
              
              end
              else
              begin
              
                haddr <= new_addr;
                htrans <= 2'b11;
              
              end
            
            end
            
          end
        
        end
       
        /***********************************************************************
        * PAUSE
        ***********************************************************************/
        S_PAUSE:
        begin
        
          if(~pause)                  
          begin                      
                                     
            haddr  <= new_addr;
            htrans <= 2'b11;       
            state  <= S_A;    
                                     
          end                        
            
        end
        
      endcase
    
    end
    
  end
  
  `ifdef RW_SIMU
  
    reg [16*8-1:0] state_str;
  
    always @(*)
    
      case (state)
      
        S_IDLE:  state_str = "S_IDLE";
        S_A:     state_str = "S_A";
        S_AD:    state_str = "S_AD";   
        S_D:     state_str = "S_D"; 
        S_PAUSE: state_str = "S_PAUSE";
        default: state_str = "UNDEF";
     
      endcase    
      
  `endif
  
endmodule  
    
  


