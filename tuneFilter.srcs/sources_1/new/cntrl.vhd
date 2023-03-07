----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/10/2023 10:02:35 AM
-- Design Name: 
-- Module Name: control - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.tuneFilter_pkg.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity control is
    Port (  clk, rst, RQ    : in STD_LOGIC;
            input           : in std_logic_vector(c_data_w-1 downto 0);
            GNT, RDY, en    : out STD_LOGIC;
            output          : out std_logic_vector(c_data_w-1 downto 0));
end control;

architecture Behavioral of control is
--types----------------------------------------------------------------------------
type t_state is (idle, write, read, run, rerun);
--signals--------------------------------------------------------------------------
signal sample_mem : t_sample_mem := ( --sample memory
    "0000001011111101", "1000101111100001", "0011101000011001", 
    others => (others => '0'));
signal coeff_mem : t_coeff_mem := ( --coefficient memory in order: s1, a2, a3, b2, b3
    "0000001011111101", "1000101111100001", "0011101000011001", "0111111111111111", "0100000000000000",
    others => (others => '0')); 
signal wdata_sample, wdata_coeff, rdata_sample, rdata_coeff : signed(c_data_w-1 downto 0) := (others => '0'); --read and write signals
signal waddr_sample, raddr_sample : unsigned(c_len_sample_mem-1 downto 0) := (others => '0');
signal waddr_coeff, raddr_coeff : unsigned(c_len_coeff_mem-1 downto 0) := (others => '0');
signal we_sample_mem, we_coeff_mem : std_logic;
signal new_delay, result : signed(c_data_w-1 downto 0);
signal state, next_state : t_state := idle; 
signal RQ_c, RQ_s, GNT_c, RDY_c, en_cnt_coeff, en_cnt_section : std_logic := '0';
signal cnt_coeff_c, cnt_coeff_s :  unsigned(c_len_cnt_coeff-1 downto 0) := (others => '0');
signal cnt_sample :  unsigned(c_len_cnt_sample-1 downto 0) := (others => '0');
signal cnt_section_c, cnt_section_s : unsigned(c_len_cnt_section-1 downto 0) := (others => '0');
-----------------------------------------------------------------------------------
begin
    p_reg: process (clk, rst)
        begin
            if rst = '1' then
                new_delay <= (others => '0');
                result <= (others => '0');
                state <= idle;
                output <= (others => '0');
                GNT <= '0';
                RDY <= '0';
                RQ_c <= '0';
                RQ_s <= '0';
                cnt_coeff_s <= (others => '0');
                cnt_section_s <= (others => '0');
                --cnt_section_s <= (others => '0');
            elsif rising_edge(clk) then
                state <= next_state;
                --output registers
                output <= std_logic_vector(rdata_sample);
                GNT <= GNT_c;
                RDY <= RDY_c;
                --data sync ddff
                RQ_c <= RQ;
                RQ_s <= RQ_c;
                --counter register
                cnt_coeff_s <= cnt_coeff_c;
                cnt_section_s <= cnt_section_c;      
            end if;
        end process;

    p_counters: process (en_cnt_coeff, cnt_coeff_s)
        begin
            cnt_coeff_c <= (others => '0');
            cnt_section_c <= (others => '0');
            cnt_sample <= (others => '0'); 
            --coefficient memory counter
            if en_cnt_coeff = '1' then
                cnt_coeff_c <= cnt_coeff_s + 1;
            end if;
            if (en_cnt_section = '1') then
                if cnt_coeff_s = (2*c_s_order) then
                    cnt_section_c <= cnt_section_s + 1;
                else
                    cnt_section_c <= cnt_section_s;
                end if;
            end if;
            --sample memory mux
            case (cnt_coeff_s) is
                when to_unsigned(0,c_len_cnt_coeff) => cnt_sample <= to_unsigned(0,c_len_cnt_sample);
                when to_unsigned(1,c_len_cnt_coeff) => cnt_sample <= to_unsigned(1,c_len_cnt_sample);
                when to_unsigned(2,c_len_cnt_coeff) => cnt_sample <= to_unsigned(2,c_len_cnt_sample);
                when to_unsigned(3,c_len_cnt_coeff) => cnt_sample <= to_unsigned(1,c_len_cnt_sample);
                when to_unsigned(4,c_len_cnt_coeff) => cnt_sample <= to_unsigned(2,c_len_cnt_sample);
                when others => null; 
            end case;

        end process;

    p_fsm: process (state, RQ_s, input, cnt_sample, cnt_coeff_s, cnt_section_s, waddr_sample)
        begin
            GNT_c <= '0';
            RDY_c <= '0';
            en  <= '0';
            we_sample_mem <= '0';
            en_cnt_coeff <= '0';
            en_cnt_section <= '0';
            --rdata_sample <= (others => '0');
            wdata_sample <= (others => '0');
            raddr_sample <= (others => '0');
            waddr_sample <= (others => '0'); 
            case (state) is
                when idle =>
                    RDY_c <= '0';
                    GNT_c <= '0';
                    we_sample_mem <= '0';
                    if RQ_s = '1' then --data valid
                        waddr_sample <= resize(cnt_sample,waddr_sample'length); --set write address
                        wdata_sample <= signed(input); --set data to be writen to
                        GNT_c <= '1';
                        we_sample_mem <= '1';   --write enable
                        next_state <= write; --go to write
                    else
                        next_state <= idle;
                    end if;

                when write =>
                    we_sample_mem <= '0';   --pull down after 1 clk
                     
                    if RQ_s = '0' then  --when acknoledged by master, go to read
                        raddr_sample <= waddr_sample;
                        RDY_c <= '1';
                        next_state <= read;
                    else
                        next_state <= write;
                    end if;

                when read =>
                    RDY_c <= '0'; --signal that rdata is valid
                    next_state <= run;
                
                when run =>
                    en_cnt_coeff <= '1';
                    en_cnt_section <= '1';
                    raddr_coeff <= resize(cnt_coeff_s+cnt_section_s, raddr_coeff'length);
                    raddr_sample <= resize(cnt_sample+cnt_section_s, raddr_sample'length);
                    
                    if (cnt_coeff_s < (2*c_s_order-1)) AND (cnt_section_s < (c_f_order/c_s_order-1)) then
                        next_state <= run;
                    elsif (cnt_coeff_s >= (2*c_s_order-1)) AND (cnt_section_s < (c_f_order/c_s_order-1)) then
                        next_state <= rerun;
                    elsif (cnt_coeff_s >= (2*c_s_order-1)) AND (cnt_section_s >= c_f_order/c_s_order-1) then
                        RDY_c <= '1';
                        next_state <= idle;
                    end if;

                when rerun =>
                    en_cnt_coeff <= '0';
                    en_cnt_section <= '1';
                    next_state <= run;
                    --TODO: next_state <= memory_write (shift sample and overwrite delay(0) with new one)
                when others =>
                    next_state <= idle;

            end case;
        end process;

    p_sample_memory: process (clk, rst, we_sample_mem, wdata_sample, waddr_sample)
        --sample_mem write
        begin
            if rst = '1' then
                sample_mem <= (others => (others => '0'));
            elsif rising_edge(clk) then
                if we_sample_mem = '1' then
                    sample_mem(to_integer(waddr_sample)) <= wdata_sample; --write
                end if;
            end if;
        end process;
        --sample memory read
        rdata_sample <= sample_mem(to_integer(raddr_sample)); --read

    p_coeff_memory: process (clk, we_coeff_mem, wdata_coeff, waddr_coeff)
        --coefficient memory write
        begin
            if rst = '1' then
                coeff_mem <= (others => (others => '0'));
            elsif rising_edge(clk) then
                if we_coeff_mem = '1' then
                    coeff_mem(to_integer(waddr_coeff)) <= wdata_coeff; --write
                end if;
            end if;
        end process;
        --coefficient memory read
        rdata_coeff <= coeff_mem(to_integer(raddr_coeff)); --read

end Behavioral;
