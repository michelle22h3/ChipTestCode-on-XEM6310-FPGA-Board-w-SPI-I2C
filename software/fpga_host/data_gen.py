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
    def write_byte(cls, addr:int, data:int):
        """
        :return: the generate a 4 byte data byte array.
        """
        assert 0 < addr < 6 and 0 <= data <= 255, "Invalid size provided."
        w_four_byte = [0, 1, addr, data]
        return bytearray(w_four_byte)

    # @classmethod
    # def indir_write(cls, addr:int, data:int):

    

