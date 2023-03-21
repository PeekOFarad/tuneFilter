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
signal sample_mem : t_sample_mem := (others => (others => '0'));
signal coeff_mem : t_coeff_mem := (others => (others => '0')); 
signal wdata_sample, wdata_coeff, rdata_sample, rdata_sample_s, rdata_coeff, rdata_coeff_s : signed(c_data_w-1 downto 0) := (others => '0'); --read and write signals
signal waddr_sample, raddr_sample : unsigned(c_len_sample_mem-1 downto 0) := (others => '0');
signal waddr_coeff, raddr_coeff : unsigned(c_len_coeff_mem-1 downto 0) := (others => '0');
signal we_sample_mem, we_coeff_mem, re_delay : std_logic := '0';
signal delay : signed(c_data_w-1 downto 0) := (x"0001");
signal new_delay_c, new_delay_s : signed(c_data_w-1 downto 0) := (x"0002");
signal result : signed(c_data_w-1 downto 0) := (x"0003");
signal state, next_state : t_state := idle; 
signal RQ_c, RQ_s, GNT_c, RDY_c, en_cnt_coeff, en_cnt_section, en_acc, en_acc0, en_acc1, en_result : std_logic := '0';
signal cnt_coeff_c, cnt_coeff_s :  unsigned(c_len_cnt_coeff-1 downto 0) := (others => '0');
signal cnt_sample :  unsigned(c_len_cnt_sample-1 downto 0) := (others => '0');
signal cnt_section_c, cnt_section_s : unsigned(c_len_cnt_section downto 0) := (others => '0');
signal mul, mul_pipe_c, mul_pipe_s : signed(c_mul_w-1 downto 0) := (others => '0');
signal acc_c, acc_s : signed(c_acc_w-1 downto 0) := (others => '0');
signal acc : signed(c_acc_w downto 0) := (others => '0');
signal delay_cast : signed(c_data_w+(c_acc_w-c_mul_w)-1 downto 0) := (others => '0');
-----------------------------------------------------------------------------------
begin
    p_reg: process (clk, rst)
        begin
            if rst = '1' then
                new_delay_s <= (others => '0');
                result <= (others => '0');
                state <= idle;
                output <= (others => '0');
                GNT <= '0';
                RDY <= '0';
                RQ_c <= '0';
                RQ_s <= '0';
                cnt_coeff_s <= (others => '0');
                cnt_section_s <= (others => '0');
                en_acc0 <= '0';
                en_acc1 <= '0';
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
                --arithmetic regiters
                mul_pipe_s <= mul_pipe_c;
                if en_acc0 = '1' then
                    acc_s <= acc_c;
                    mul_pipe_s <= mul_pipe_c;
                else
                    acc_s <= (others => '0');
                    mul_pipe_s <= (others => '0');
                end if;
                --work registers
                if cnt_coeff_s = 4 then
                    new_delay_s <= new_delay_c; --feddback result
                end if;
                if cnt_coeff_s = 6 then
                    result <= new_delay_c; --section result
                end if;
                --enable signals
                en_acc0 <= en_cnt_coeff;
                en_acc1 <= en_acc0;
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
            --re_sample_mem <= '0';
            --counter enables
            en_cnt_coeff <= '0';
            en_cnt_section <= '0';
            --signals
            wdata_sample <= (others => '0');
            raddr_sample <= (others => '0');
            waddr_sample <= (others => '0');
            raddr_coeff <= (others => '0');
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
                    --re_sample_mem <= '1';
                    if cnt_coeff_s <= (2*c_s_order) then
                        raddr_coeff <= resize(cnt_coeff_s+(2*c_s_order+1)*cnt_section_s, raddr_coeff'length);
                        raddr_sample <= resize(cnt_sample+(c_s_order+1)*cnt_section_s, raddr_sample'length);
                    end if;
                    if cnt_coeff_s > (2*c_s_order) then
                        next_state <= read_delay;
                    else
                        next_state <= run;  
                    end if;
                    
-------------------------- memory rewrite
                when read_delay =>
                    en_cnt_section <= '1';
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
                    wdata_sample <= new_delay_s;
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

    p_mul: mul_pipe_c <= rdata_sample_s * rdata_coeff_s;
    
    p_en_acc: en_acc <= en_acc0 OR en_acc1;

    p_en_result : en_result <= (en_cnt_section)AND NOT(en_acc OR en_cnt_coeff);

    p_acc: acc <= resize(acc_s, c_acc_w+1) + resize(mul_pipe_s, c_acc_w+1);

    p_acc_overflow: acc_c <=    ('0'&(c_acc_w-2 downto 0 => '1')) when ((acc(c_acc_w) = '0') AND (acc(c_acc_w-1) /= '0')) else
                                ('1'&(c_acc_w-2 downto 0 => '0')) when ((acc(c_acc_w) = '1') AND (acc(c_acc_w-1) /= '1')) else
                                acc(c_acc_w-1 downto 0);

    p_new_delay: new_delay_c <= ('0'&(c_data_w-2 downto 0 => '1')) when ((acc(c_acc_w) = '0') AND (acc(c_acc_w-1 downto c_acc_w-6) /= 0)) else
                                ('1'&(c_data_w-2 downto 0 => '0')) when ((acc(c_acc_w) = '1') AND (acc(c_acc_w-1 downto c_acc_w-6) /= 1)) else
                                acc(c_acc_w-6 downto (c_acc_w-6)-(c_data_w-1));

    p_sample_memory: process (clk, rst, we_sample_mem, wdata_sample, waddr_sample)
    --sample memory write
    begin
        if rst = '1' then
            sample_mem <= (x"2000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", others => (others => '0'));
        elsif rising_edge(clk) then
            if we_sample_mem = '1' then
                sample_mem(to_integer(waddr_sample)) <= wdata_sample; --write
            end if;
            rdata_sample_s <= sample_mem(to_integer(raddr_sample)); --read
        end if;
    end process;

    p_coeff_memory: process (clk, we_coeff_mem, wdata_coeff, waddr_coeff)
    --coefficient memory write
    begin
        if rst = '1' then
            coeff_mem <= ( --coefficient memory in order: s1, a2, a3, b2, b3
            "0001000110101011",  "0001000010101111",  "0001010111111100",  "0100000000000000",  "0010000000000000",
            "0000110110110100",  "0000110011110001",  "0000100111100000",  "0100000000000000",  "0010000000000000",
            "0000101110110010",  "0000101100001011",  "0000001110111101",  "0100000000000000",  "0010000000000000",
            "0000101011010110",  "0000101000111100",  "0000000100011101",  "0100000000000000",  "0010000000000000",
            others => (others => '0'));
        elsif rising_edge(clk) then
            if we_coeff_mem = '1' then
                coeff_mem(to_integer(waddr_coeff)) <= wdata_coeff; --write
            end if;
            rdata_coeff_s <= coeff_mem(to_integer(raddr_coeff)); --read
        end if;
    end process;

end Behavioral;
