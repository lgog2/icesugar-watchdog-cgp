#pragma once

#include <array>
#include <cstdint>
#include <cstddef>

// ============================================================================
// GLOBALNE PARAMETRY ARCHITEKTURY
// ============================================================================
constexpr size_t NUM_INPUTS  = 3;	// x0(stan k60s, x1(stan k5), x2(UART)
constexpr size_t NUM_OUTPUTS = 3;	// y0(rozladowanie k60), y1(rozladowanie k5), y2(odciecie)
constexpr size_t NUM_NODES   = 30;	// liczba LUT4 dla rdzenia

// wszystkie mozliwe sygnaly (3 wejscia + 30 wyjsc z 30 LUT4 = 33)
constexpr size_t TOTAL_SIGNALS = NUM_INPUTS + NUM_NODES;

// ============================================================================
// STRUKTURY GENOTYPU [30 x [F, in0, in1, in2, in3], out0, out1, out2]
// ============================================================================

// pojedynczy LUT4 - blok genow?
struct Lut {
	uint16_t F = 0;						// funkcja logiczna LUT4 (16-bitowa tablica prawdy)
	std::array<uint8_t, 4> in = {0};	// indeksy sygnalow idacych do wejsc (x0-x2 sposrod 0-32)
};

// genotyp osobnika (jeden chromosom?) plus element fenotypu -ocena fitness
struct Individual {
	std::array<Lut, NUM_NODES> luts;		// 30 LUT4 (genotyp)
	std::array<uint8_t, NUM_OUTPUTS> out;	// indeksy sygnalow idacych do wyjsc (y0-y2 sposrod 0-32)
	int fitness = 0;						// ocena
};


// ============================================================================
// MODEL AWARII - pojedyncze uszkodzenie(SA0 / SA1)
// ============================================================================

enum class FaultPort : int8_t {
	I0   = 0,	// uszkodzenie wejscia.I0
	I1   = 1,	// uszkodzenie wejscia I1
	I2   = 2,	// uszkodzenie wejscia.I2
	I3   = 3,	// uszkodzenie wejscia.I3
	OUT  = 4	// calkowite wylaczenie LUT4 - uszkodzone wyjscie
};

enum class FaultType : int8_t {
	SA0 = 0, // zwarcie do masy(Stuck-At-0)
	SA1 = 1  // zwarcie do zasilania
};

struct FaultMask {
	int8_t target_lut = -1;				// -1: brak uszkodzenia | 0-29: indeks uszkodzonego LUT
	FaultPort port = FaultPort::OUT;
	FaultType type = FaultType::SA0;
	// sprawdzenia stanu
	inline bool is_active() const {
		return target_lut != -1;
	}
};
