"""
This module export data generator to generate different data patterns for testing.
"""

import random
import os
class DataGen:

    @classmethod
    def constant_array(cls, size: int, constant: int) -> bytearray:
        """
        Helper to generate the data array with the specified constant value.
        :param size: number of bytes in the result.
        :param constant: the specified value of constant value.
        :return: the generate data byte array.
        """
        assert size > 0 and 0 <= constant < 256, "Invalid size or constant size provided."
        return bytearray([constant] * size)

    @classmethod
    def full_zeros(cls, size: int) -> bytearray:
        """Handy alias for full 0s constant array."""
        return cls.constant_array(size, 0)

    @classmethod
    def full_ones(cls, size):
        """Handy alias for full 1s constant array."""
        return cls.constant_array(size, 1)

    @classmethod
    def indir_writedata(cls, addr:int, msb_data: int, lsb_data: int) -> bytearray:
        """Helper to generate the data for an indiect writing."""
        byte_of_16 = [0, 1, 2, addr, 0, 1, 3, lsb_data, 0, 1, 4, msb_data, 0, 1, 1, 3]
        return bytearray(byte_of_16)
     

    @classmethod
    def random_array(cls, size: int):
        """
        Helper to generate the data array with the random number in the array.
        :param size: number of bytes in the result.
        :return: the generate data byte array.
        """
        assert size > 0, "Invalid size provided."
        random_list = [random.randint(0, 15) for _ in range(size)]
        return bytearray(random_list)

    @classmethod
    def write_byte(cls, addr:int, data:int) -> bytearray:
        """
        :return: the generate a 4 byte data byte array.
        """
        assert 0 < addr <= 6 and 0 <= data <= 255, "Invalid size provided."
        w_four_byte = [data, addr, 1, 0]
        return bytearray(w_four_byte)

    @classmethod
    def read_byte(cls, addr:int) -> bytearray:
        """
        :return: the generate a 4 byte data byte array.
        """
        assert 0 < addr <= 6 , "Invalid addr provided."
        r_four_byte = [0, addr, 0, 0]
        return bytearray(r_four_byte)

    @classmethod
    def indir_write(cls, ind_addr:int, ind_data:int) -> bytearray:
        """
        :return: 4 x 4 = 16 byte array.
        """
        send_waddr = cls.write_byte(0x02, ind_addr)          # Send Address of inner reg
        send_data = ind_data.to_bytes(2,"big")
        send_data_lsb = cls.write_byte(0x03, send_data[1])   # Send lsb of data
        send_data_msb = cls.write_byte(0x04, send_data[0])  # Send msb of data      
        send_w_oper = cls.write_byte(0x01, 0x03)            # Operation: Writing
        send_waddr.extend(send_data_lsb)
        send_waddr.extend(send_data_msb)
        send_waddr.extend(send_w_oper)
        return send_waddr
    
    @classmethod
    def indir_read(cls, ind_addr:int) -> bytearray:
        """
        :return:4 x 4 = 16 byte array.
        """
        send_raddr  = cls.write_byte(0x02, ind_addr)          # Send Address of inner reg
        send_r_oper = cls.write_byte(0x01, 0x02)               # Operation: Reading
        send_rmsb   = cls.read_byte(0x06)  
        send_rlsb   = cls.read_byte(0x05)
        send_raddr.extend(send_r_oper)
        send_raddr.extend(send_rmsb)
        send_raddr.extend(send_rlsb)
        return send_raddr
    
    @classmethod
    def test_write(cls) -> bytearray:
        to_be_send =[0xAA,0x02,0x01,0x00,  0xBB,0x02,0x01,0x00,  0xCC,0x03,0x01,0x00 , 0xDD,0x04,0x01,0x00]
        out_16byte=bytearray(to_be_send)
        return out_16byte

    @classmethod
    def test_read(cls) -> bytearray:
        to_be_send =[0x00,0x02,0x00,0x00,  0x00,0x03,0x00,0x00,  0x00,0x04,0x00,0x00 , 0x00,0x05,0x00,0x00]
        out_16byte=bytearray(to_be_send)
        return out_16byte


        
