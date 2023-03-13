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
type t_state is (idle, write, read, run, write_delay, write_new_delay, write_result, read_delay);
--signals--------------------------------------------------------------------------
signal sample_mem : t_sample_mem := ( --sample memory
    "0000001011111101", "1000101111100001", "0011101000011001", 
    others => (others => '0'));
signal coeff_mem : t_coeff_mem := ( --coefficient memory in order: s1, a2, a3, b2, b3
    "0000001011111101", "1000101111100001", "0011101000011001", "0111111111111111", "0100000000000000",
    others => (others => '0')); 
signal wdata_sample, wdata_coeff, rdata_sample, rdata_sample_s, rdata_coeff, rdata_coeff_s : signed(c_data_w-1 downto 0) := (others => '0'); --read and write signals
signal waddr_sample, raddr_sample : unsigned(c_len_sample_mem-1 downto 0) := (others => '0');
signal waddr_coeff, raddr_coeff : unsigned(c_len_coeff_mem-1 downto 0) := (others => '0');
signal we_sample_mem, we_coeff_mem, re_delay, re_sample_mem : std_logic;
signal delay : signed(c_data_w-1 downto 0) := (x"0001");
signal new_delay : signed(c_data_w-1 downto 0) := (x"0002");
signal result : signed(c_data_w-1 downto 0) := (x"0003");
signal state, next_state : t_state := idle; 
signal RQ_c, RQ_s, GNT_c, RDY_c, en_cnt_coeff, en_cnt_section : std_logic := '0';
signal cnt_coeff_c, cnt_coeff_s :  unsigned(c_len_cnt_coeff-1 downto 0) := (others => '0');
signal cnt_sample :  unsigned(c_len_cnt_sample-1 downto 0) := (others => '0');
signal cnt_section_c, cnt_section_s : unsigned(c_len_cnt_section downto 0) := (others => '0');
-----------------------------------------------------------------------------------
begin
    p_reg: process (clk, rst)
        begin
            if rst = '1' then
                new_delay <= (x"0002");--(others => '0');
                result <= (x"0003");--(others => '0');
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
                if RDY_c = '1' then --temporary output
                    output <= std_logic_vector(result);
                end if;
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
            --section counter
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

    p_fsm: process (state, RQ_s, input, cnt_sample, cnt_coeff_s, cnt_section_s, waddr_sample, rdata_sample_s)
        begin
            GNT_c <= '0';
            RDY_c <= '0';
            en  <= '0';
            --write enables
            we_sample_mem <= '0';
            we_coeff_mem <= '0';
            --read enables
            re_delay <= '0';
            re_sample_mem <= '0';
            --counter enables
            en_cnt_coeff <= '0';
            en_cnt_section <= '0';
            --signals
            wdata_sample <= (others => '0');
            raddr_sample <= (others => '0');
            waddr_sample <= (others => '0');
            case (state) is
                when idle =>
                    if RQ_s = '1' then --data valid
                        GNT_c <= '1';
                        next_state <= run; --go to write
                    else
                        next_state <= idle;
                    end if;
                
                when run =>
                    en_cnt_coeff <= '1';
                    en_cnt_section <= '1';
                    re_sample_mem <= '1';
                    raddr_coeff <= resize(cnt_coeff_s+(2*c_s_order+1)*cnt_section_s, raddr_coeff'length);
                    raddr_sample <= resize(cnt_sample+(c_s_order+1)*cnt_section_s, raddr_sample'length);

                    if cnt_coeff_s > (2*c_s_order-1) then
                        next_state <= read_delay;
                    else
                        next_state <= run;  
                    end if;
                    
-------------------------- memory rewrite
                when read_delay =>
                    en_cnt_section <= '1';
                    --re_sample_mem <= '1';
                    raddr_sample <= to_unsigned(1+3*(to_integer(cnt_section_s)-1), raddr_sample'length); --read delay(0)
                    next_state <= write_delay;

                when write_delay =>
                    en_cnt_section <= '1';
                    we_sample_mem <= '1';
                    waddr_sample <= to_unsigned(2+3*(to_integer(cnt_section_s)-1), waddr_sample'length);
                    wdata_sample <= rdata_sample_s; --delay(1) <= delay(0)
                    next_state <= write_new_delay;

                when write_new_delay =>
                    en_cnt_section <= '1';
                    we_sample_mem <= '1';
                    waddr_sample <= to_unsigned(1+3*(to_integer(cnt_section_s)-1), waddr_sample'length);
                    wdata_sample <= new_delay;
                    next_state <= write_result;

                when write_result =>
                    en_cnt_section <= '1';
                    we_sample_mem <= '1';
                    
                    if (cnt_section_s > c_f_order/c_s_order-1) then
                        RDY_c <= '1';
                        GNT_c <= '1';
                        next_state <= idle;
                    else
                        waddr_sample <= to_unsigned(3+3*(to_integer(cnt_section_s)-1), waddr_sample'length);
                        wdata_sample <= result;
                        next_state <= run;
                    end if;

                when others =>
                    next_state <= idle;

            end case;
        end process;

    --cnt_rewrite <= not(cnt_rewrite_s)-1;
    p_sample_memory: process (clk, rst, we_sample_mem, wdata_sample, waddr_sample)
        --sample_mem write
        begin
            if rst = '1' then
                sample_mem <= (x"0000", x"0023", x"0000", x"0000", x"0023", x"0000", x"0000", x"0023", x"0000", x"0000", x"0023", x"0000");
            elsif rising_edge(clk) then
                if we_sample_mem = '1' then
                    sample_mem(to_integer(waddr_sample)) <= wdata_sample; --write
                end if;
                rdata_sample_s <= sample_mem(to_integer(raddr_sample)); --read
            end if;
        end process;
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
                rdata_coeff_s <= coeff_mem(to_integer(raddr_coeff)); --read
            end if;
        end process;
        --coefficient memory asynchronous read
        rdata_coeff <= coeff_mem(to_integer(raddr_coeff)); --read

end Behavioral;
