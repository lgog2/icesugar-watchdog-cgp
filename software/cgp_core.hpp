#pragma once

#include <iostream>
#include <fstream>
#include <random>
#include <string>
#include "cgp_types.hpp"

// generator liczb losowych 32bitowy okres 2^19937
extern std::mt19937 rng;


inline Individual create_seed() {
	Individual ind;

	// kazdy kolejny lut ma do dyspozycji tylko wyjscia poprzednich - zabezpieczenie przed powstaniem petli
	// powstaje acykliczny graf skierowany
	std::uniform_int_distribution<size_t> dist_lut0(0, 2); // tylko wejscia x0, x1, x2
	std::uniform_int_distribution<size_t> dist_lut1(0, 3); // dodatkowo wyjscie z lut_0
	std::uniform_int_distribution<size_t> dist_lut2(0, 4); // dodatkowo wyjscie z lut_1

	// LUT_0: y0 = (x2 & !x0) | x1
	// wymaga wejść x0, x1, x2 na I0, I1, I2. ; port I3 jest przypisany losowo (sposrod mozliwych - komentarz wyzej)
	ind.luts[0].in = {
		0, //x0
		1, //x1
		2, //x2
		static_cast<uint8_t>(dist_lut0(rng))

	};

	// LUT_1: y1 = !x0
	// wymaga wejscia x0 na I0.; porty I1, I2, I3 przypisane losowo
	ind.luts[1].in = {
		0, //x0
		static_cast<uint8_t>(dist_lut1(rng)),
		static_cast<uint8_t>(dist_lut1(rng)),
		static_cast<uint8_t>(dist_lut1(rng))
	};

	// LUT_2: y2 = x0 & !x1
	// wymaga wejsc x0 i x1 na I0 i I1. ; porty I2, I3 przypisane losowo
	ind.luts[2].in = {
		0,
		1,
		static_cast<uint8_t>(dist_lut2(rng)),
		static_cast<uint8_t>(dist_lut2(rng))
	};


	/* wizualizacja funkcji F dla poszczegolnych rownan- tablica prawdy LUT_INIT:
	*
	*                     || lut_0 (y0) = (I2 & ~I0) | I1
	*                     || lut_1 (y1) = ~I0
	*                     || lut_2 (y2) = I0 & ~I1
	* ----------------------------------------------------------------------------
	* ADRES | I3 I2 I1 I0 || lut_0 | lut_1  | lut_2| - mozliwe 65536 takich kombinacji
	* (Dec) |  8  4  2  1 || y0_out| y1_out| y2_out|   (tu tylko 3 odpowiadajace rownaniom ziarna)
	* ---------------------------------------------------------------------------
	*   0   |  0  0  0  0 ||   0   |   1   |   0   |
	*   1   |  0  0  0  1 ||   0   |   0   |   1   |
	*   2   |  0  0  1  0 ||   1   |   1   |   0   |
	*   3   |  0  0  1  1 ||   1   |   0   |   0   |
	*   4   |  0  1  0  0 ||   1   |   1   |   0   |
	*   5   |  0  1  0  1 ||   0   |   0   |   1   |
	*   6   |  0  1  1  0 ||   1   |   1   |   0   |
	*   7   |  0  1  1  1 ||   1   |   0   |   0   |
	* ----------------------------------------------------------------------------
	*   8   |  1  0  0  0 ||   0   |   1   |   0   |
	*   9   |  1  0  0  1 ||   0   |   0   |   1   |
	*  10   |  1  0  1  0 ||   1   |   1   |   0   |
	*  11   |  1  0  1  1 ||   1   |   0   |   0   |
	*  12   |  1  1  0  0 ||   1   |   1   |   0   |
	*  13   |  1  1  0  1 ||   0   |   0   |   1   |
	*  14   |  1  1  1  0 ||   1   |   1   |   0   |
	*  15   |  1  1  1  1 ||   1   |   0   |   0   |
	* ----------------------------------------------------------------------------
	*
	* lut_0.F = 16'hDCDC  (Bin: 16'b1101_1100_1101_1100, Dec: 16'd56540)
	* lut_1.F = 16'h5555  (Bin: 16'b0101_0101_0101_0101, Dec: 16'd21845)
	* lut_2.F = 16'h2222  (Bin: 16'b0010_0010_0010_0010, Dec: 16'd8738)
	*
	* ----------------------------------------------------------------------------*/
	// budowanie automatyczne funkcji F - kolejno po jednym bicie poczynajac od najmlodszego:
	for (uint16_t lut_idx = 0; lut_idx < 16; ++lut_idx) {
		//wyodrebnienie wartosci wejsc 0-2 dla danej kombinacji wartosci na wejsciach
		uint8_t i0 = lut_idx & 1;
		uint8_t i1 = (lut_idx >> 1) & 1;
		uint8_t i2 = (lut_idx >> 2) & 1;

		if (((i2 & !i0) | i1) & 1) {
			//LUT0 -ustawianie odpowiedniego bitu jezeli rownanie daje 1 dla tej kombinacji wejsc
			ind.luts[0].F |= (1 << lut_idx); // poczatkowo F wyzerowana
		}
		if ((!i0) & 1) {
			//LUT1 -ustawianie odpowiedniego bitu jezeli rownanie daje 1 dla tej kombinacji wejsc
			ind.luts[1].F |= (1 << lut_idx);
		}
		if ((i0 & !i1) & 1) {
			//LUT2 -ustawianie odpowiedniego bitu jezeli rownanie daje 1 dla tej kombinacji wejsc
			ind.luts[2].F |= (1 << lut_idx);
		}
	}

	// pozostale LUT (3 - 29) - losowo skonfigurowane (Junk DNA)
	std::uniform_int_distribution<uint16_t> dist_f(0, 65535);
	for (size_t i = 3; i < NUM_NODES; ++i) {
		ind.luts[i].F = dist_f(rng); //losowa funkcja logiczna
		for (size_t j = 0; j < 4; ++j) {
			// losowe podlaczanie wejsc LUT4 - tylko z wejść x0-x2 LUB wyjsc LUT o nizszym indeksie
			std::uniform_int_distribution<size_t> dist_in(0, NUM_INPUTS + i - 1);
			ind.luts[i].in[j] = static_cast<uint8_t>(dist_in(rng));
		}
	}

	// przypisanie wyjsc poszczegolnych LUT do wyjsc y0-y2 (do wrappera)
	ind.out[0] = static_cast<uint8_t>(NUM_INPUTS + 0); //  3->y0
	ind.out[1] = static_cast<uint8_t>(NUM_INPUTS + 1); //  4->y1
	ind.out[2] = static_cast<uint8_t>(NUM_INPUTS + 2); //  5->y2

	return ind;
}

//----------------------------------------------------------------------------------------------------------
// parametry mutacji:
//----------------------------------------------------------------------------------------------------------
constexpr double MUTATION_RATE_F = 0.033; // 3.3% szans na mutacje tabeli prawdy LUT (funkcja F)
// 30LUT * 1funkcja F = 30genow
// (wartosc oczekiwana liczby mutacji) E = 30 * 0.033 = ok 1

constexpr double MUTATION_RATE_IN = 0.008; // 0.8% szans na przepiecie wejscia/wyjscia
// 30LUT * 4wejscai + 3wyjscia = 123geny
// (wartosc oczekiwana liczby mutacji) E = 123 * 0.08 = ok 1
//
//w sumie spodziewane wiec ok 2 mutace na pokolenie
//
//
inline Individual mutate(const Individual& parent) {
	Individual child = parent;

	std::uniform_real_distribution<double> prob(0.0, 1.0);
	std::uniform_int_distribution<uint16_t> dist_f(0, 65535);

	for (size_t i = 0; i < NUM_NODES; ++i) {

		// mutacja funkcji logicznej
		if (prob(rng) < MUTATION_RATE_F) {
			//nowa losaowa funkcja logiczna - jedna z 65536 mozliwych
			child.luts[i].F = dist_f(rng);
		}

		// mutacja polaczen wewnatrz
		for (size_t j = 0; j < 4; ++j) {
			if (prob(rng) < MUTATION_RATE_IN) {
				// losowe przepiecie do jednego z wejsci zewnetrznych x0-x2 lub jednego z wyjsc juz obsluzonych lut
				// co gwarantuje zachowanie struktury acyklicznej
				std::uniform_int_distribution<size_t> dist_in(0, NUM_INPUTS + i - 1);
				child.luts[i].in[j] = static_cast<uint8_t>(dist_in(rng));
			}
		}
	}

	// mutacja polaczen z wyjsciami zewnetrznymi y0-y2
	for (size_t i = 0; i < NUM_OUTPUTS; ++i) {
		if (prob(rng) < MUTATION_RATE_IN) {
			std::uniform_int_distribution<size_t> dist_out(NUM_INPUTS, TOTAL_SIGNALS - 1);
			child.out[i] = static_cast<uint8_t>(dist_out(rng));
		}
	}

	return child;
}

// symulacja osobnika
inline uint8_t simulate(const Individual& ind, uint8_t x0, uint8_t x1, uint8_t x2, const FaultMask& fault) {

	// wszystkie mozliwe sygnaly (3 wejscia + 30 wyjsc z 30 LUT4 = 33)
	std::array<uint8_t, TOTAL_SIGNALS> signals = {0};
	signals[0] = x0 & 1;
	signals[1] = x1 & 1;
	signals[2] = x2 & 1;

	// propagacja sygnalow
	for (size_t i = 0; i < NUM_NODES; ++i) {

		bool is_faulty_node = fault.is_active() && (static_cast<int>(i) == fault.target_lut);
		uint8_t fault_val = static_cast<uint8_t>(fault.type);

		// jezeli uszkodzone wyjscie
		if (is_faulty_node && fault.port == FaultPort::OUT) {
			signals[NUM_INPUTS + i] = fault_val;
			continue;
		}

		// stany wejsc do aktualnego LUT
		uint8_t idx0 = signals[ind.luts[i].in[0]];
		uint8_t idx1 = signals[ind.luts[i].in[1]];
		uint8_t idx2 = signals[ind.luts[i].in[2]];
		uint8_t idx3 = signals[ind.luts[i].in[3]];

		// jezeli uszkodzone jedno z wejsc
		if (is_faulty_node) {
			if (fault.port == FaultPort::I0) idx0 = fault_val;
			else if (fault.port == FaultPort::I1) idx1 = fault_val;
			else if (fault.port == FaultPort::I2) idx2 = fault_val;
			else if (fault.port == FaultPort::I3) idx3 = fault_val;
		}

		// zlozenie stanow wejsc w kombinacje stanowiaca adres dla pamięci SRAM LUT
		uint8_t lut_address = (idx3 << 3) | (idx2 << 2) | (idx1 << 1) | idx0;

		// odczyt wartosci funkcji F LUT i wystawienie na wyjscie
		signals[NUM_INPUTS + i] = (ind.luts[i].F >> lut_address) & 1;
	}

	uint8_t y0 = signals[ind.out[0]];
	uint8_t y1 = signals[ind.out[1]];
	uint8_t y2 = signals[ind.out[2]];

	return (y2 << 2) | (y1 << 1) | y0;
}

// funkcja celu (weryfikacja wydlug rownan wzorcowych calej tablicy kombinacji dla trzech wejsc - wartosci 0-7)
inline int evaluate_fitness(const Individual& ind, const FaultMask& fault) {
	int score = 0;

	// kolejne sprawdzanie kazdej kmbinacji wejsc
	for (uint8_t state = 0; state < 8; ++state) {
		// wyodrebnienie poszczegolnych wejsc
		uint8_t x0 = state & 1;
		uint8_t x1 = (state >> 1) & 1;
		uint8_t x2 = (state >> 2) & 1;

		// oczekiwane wartosci wyjsc zlozone w jeden uint8_t
		uint8_t target_y0 = (x2 & !x0) | x1;
		uint8_t target_y1 = !x0;
		uint8_t target_y2 = x0 & !x1;
		uint8_t expected_vector = (target_y2 << 2) | (target_y1 << 1) | target_y0;

		uint8_t actual_vector = simulate(ind, x0, x1, x2, fault);

		if ((expected_vector & 1) == (actual_vector & 1)) score++; // y0
		if ((expected_vector & 2) == (actual_vector & 2)) score++; // y1
		if ((expected_vector & 4) == (actual_vector & 4)) score++; // y2
	}
	return score; // maksymalny wynik: 24 punkty
}

// generowanie kodu verilog dla osobnika (genotyp -> fenotyp)
inline void generateVerilog(const Individual& ind, const std::string& filename, const FaultMask& fault) {
	std::ofstream file(filename);
	file << "module cgp_core (\n"
			<< "	input  wire [" << (NUM_INPUTS - 1) << ":0] x,\n"
			<< "	output wire [" << (NUM_OUTPUTS - 1) << ":0] y\n"
			<< ");\n\n";

	// wejscia:
    for (size_t i = 0; i < NUM_INPUTS; ++i) {
        file << "    wire sig_" << i << " = x[" << i << "];\n";
    }

	// wyjscia z LUT [(* keep = 1 *) - konieczne aby kompilator nie usunał nieuzywanych wire]
	for (size_t i = 0; i < NUM_NODES; ++i) {
		file << "	(* keep = 1 *) wire sig_" << (i + NUM_INPUTS) << ";\n";
	}
	file << "\n";

	// generowanie zabezpieczonych przed optymalizacja kompilatora(* keep = 1 *) bramek LUT z uwzglednieniem FaultMask
	for (size_t i = 0; i < NUM_NODES; ++i) {
		size_t node_index = i + NUM_INPUTS;

		// sprawdzenie czy ten LUT jest celem awarii
		bool is_faulty_node = fault.is_active() && (static_cast<int>(i) == fault.target_lut);
		std::string fault_val = (fault.type == FaultType::SA1) ? "1'b1" : "1'b0";

		// awaria wyjscia - cala bramka nieaktywna
		if (is_faulty_node && fault.port == FaultPort::OUT) {
			file << "   	// [FAULT INJECTED] Zwarcie wyjscia SA" << static_cast<int>(fault.type) << "\n";
			file << "   	assign sig_" << node_index << " = " << fault_val << ";\n\n";
			continue; // pomieniecie generowania tego SB_LUT4
		}

		file << "	(* keep = 1 *) SB_LUT4 #(\n"
			 << "		.LUT_INIT(16'h";

		// formatowanie heksadecymalne funkcji F dla kazdego LUT
		auto flags = file.flags();
		file << std::hex << std::uppercase;
		file.width(4); file.fill('0');
		file << ind.luts[i].F;
		file.flags(flags);

		// awaria wejscia (nadpisanie stalego 0 lub 1 dla odpowiedniego wejscia)
		std::string i0 = (is_faulty_node && fault.port == FaultPort::I0) ? fault_val : "sig_" + std::to_string(ind.luts[i].in[0]);
		std::string i1 = (is_faulty_node && fault.port == FaultPort::I1) ? fault_val : "sig_" + std::to_string(ind.luts[i].in[1]);
		std::string i2 = (is_faulty_node && fault.port == FaultPort::I2) ? fault_val : "sig_" + std::to_string(ind.luts[i].in[2]);
		std::string i3 = (is_faulty_node && fault.port == FaultPort::I3) ? fault_val : "sig_" + std::to_string(ind.luts[i].in[3]);

		file << ")\n"
			 << "	) cell_" << i << " (\n"
			 << "		.O(sig_" << node_index << "),\n"
			 << "		.I0(" << i0 << "),\n"
			 << "		.I1(" << i1 << "),\n"
			 << "		.I2(" << i2 << "),\n"
			 << "		.I3(" << i3 << ")\n"
			 << "	);\n\n";
	}

	// mapowanie wyjsc na zawnatrz (yo-y2):
	for (size_t i = 0; i < NUM_OUTPUTS; ++i) {
		file << "	assign y[" << i << "] = sig_" << static_cast<int>(ind.out[i]) << ";\n";
	}

	file << "\nendmodule\n";
	file.close();
}


/*====================================================================================================================
  efekt generateVerilog():

module cgp_core (
	input  wire [2:0] x,
	output wire [2:0] y
);

	wire sig_0 = x[0];
	wire sig_1 = x[1];
	wire sig_2 = x[2];
	(* keep = 1 *) wire sig_3;
	(* keep = 1 *) wire sig_4;
	(* keep = 1 *) wire sig_5;
	(* keep = 1 *) wire sig_6;
	// ... tak samo dla reszty aa do sig_32 ...

	// LUT 0: y0 = (x2 & !x0) | x1   -przyklad: bramka zdrowa
	(* keep = 1 *) SB_LUT4 #(
		.LUT_INIT(16'hDCDC)
	) cell_0 (
		.O(sig_3),
		.I0(sig_0), // x0
		.I1(sig_1), // x1
		.I2(sig_2), // x2
		.I3(sig_1)  // losowe na etapie ziarna
	);

	// LUT 1: y1 = !x0   -przyklad: bramka z awaria wejscia (SA1 na I1)
	(* keep = 1 *) SB_LUT4 #(
		.LUT_INIT(16'h5555)
	) cell_1 (
		.O(sig_4),
		.I0(sig_0), // x0
		.I1(1'b1),  // <--- Nadpisane 1 (Stuck-At-1)
		.I3(sig_0)  // losowe na etapie ziarna
	);

	// LUT 2: y2 = x0 & !x1     -przyklad: awaria wyjscia (SA0 na OUT)- bramka w ogole nie syntetyzowana
	// [FAULT INJECTED] Zwarcie wyjscia SA0
	assign sig_5 = 1'b0; // <--- zwarcie do masy (nadpisanie 0)

	// ... tak samo dla kolejnych LUT (3-29) [losowe na etapie ziarna] ....

	assign y[0] = sig_3;
	assign y[1] = sig_4;
	assign y[2] = sig_5;

endmodule
*/
