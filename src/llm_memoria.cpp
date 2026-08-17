#include "llm_memoria.h"

#if defined(__APPLE__)
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/task_info.h>
#include <sys/sysctl.h>
#elif defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#elif defined(__linux__)
#include <cstdio>
// ⚠️ `<cstdlib>` NON e' superfluo, ed e' un guasto che si vede SOLO su Linux:
// `std::strtoull` vive qui, e libc++ (macOS) lo tira dentro per conto suo
// mentre libstdc++ (gcc, cioe' la CI Linux) no. Senza questa riga il job
// `build-llm (linux)` muore con «'strtoull' is not a member of 'std'» — e da
// un Mac non si vede, perche' compila.
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#endif

namespace chibi {

uint64_t memoria_impronta() {
#if defined(__APPLE__)
	task_vm_info_data_t info;
	mach_msg_type_number_t quanti = TASK_VM_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_VM_INFO,
				reinterpret_cast<task_info_t>(&info), &quanti) != KERN_SUCCESS) {
		return 0;
	}
	return static_cast<uint64_t>(info.phys_footprint);
#elif defined(__linux__)
	return memoria_residente();
#else
	// Windows lo direbbe `GetProcessMemoryInfo`, che vuole `psapi` fra le
	// librerie linkate. Non lo aggiungo da un Mac, dove non posso provarlo:
	// la CI compila Windows ma non lo ESEGUE, e una sonda che non compila
	// ferma la build di tutti per una misura. Zero è dichiarato: chi legge la
	// sonda vede «non disponibile», non un numero finto.
	return 0;
#endif
}

uint64_t memoria_residente() {
#if defined(__APPLE__)
	mach_task_basic_info_data_t info;
	mach_msg_type_number_t quanti = MACH_TASK_BASIC_INFO_COUNT;
	if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
				reinterpret_cast<task_info_t>(&info), &quanti) != KERN_SUCCESS) {
		return 0;
	}
	return static_cast<uint64_t>(info.resident_size);
#elif defined(__linux__)
	std::FILE *f = std::fopen("/proc/self/statm", "r");
	if (f == nullptr) {
		return 0;
	}
	long long totale = 0, residenti = 0;
	const int letti = std::fscanf(f, "%lld %lld", &totale, &residenti);
	std::fclose(f);
	if (letti != 2 || residenti < 0) {
		return 0;
	}
	return static_cast<uint64_t>(residenti) * static_cast<uint64_t>(sysconf(_SC_PAGESIZE));
#else
	return 0;
#endif
}

uint64_t memoria_totale_sistema() {
#if defined(__APPLE__)
	uint64_t byte = 0;
	size_t quanti = sizeof(byte);
	if (sysctlbyname("hw.memsize", &byte, &quanti, nullptr, 0) != 0) {
		return 0;
	}
	return byte;
#elif defined(_WIN32)
	MEMORYSTATUSEX s;
	s.dwLength = sizeof(s);
	if (!GlobalMemoryStatusEx(&s)) {
		return 0;
	}
	return static_cast<uint64_t>(s.ullTotalPhys);
#elif defined(__linux__)
	std::FILE *f = std::fopen("/proc/meminfo", "r");
	if (f == nullptr) {
		return 0;
	}
	char riga[256];
	uint64_t kb = 0;
	while (std::fgets(riga, sizeof(riga), f) != nullptr) {
		if (std::strncmp(riga, "MemTotal:", 9) == 0) {
			kb = std::strtoull(riga + 9, nullptr, 10);
			break;
		}
	}
	std::fclose(f);
	return kb * 1024ull;
#else
	return 0;
#endif
}

uint64_t memoria_libera_sistema() {
#if defined(__APPLE__)
	// ⚠️ LA SOMMA, E OGNI ADDENDO È UNA DECISIONE (verificata contro `vm_stat`
	// e contro il «memoria disponibile» del sistema su un M1 da 8 GB):
	//  · `free_count`      — le pagine libere (e comprende già le
	//                        speculative, che `vm_stat` mostra a parte);
	//  · `inactive_count`  — quelle che il sistema ha già messo da parte per
	//                        riprendersele: sono LA voce che rende questo
	//                        numero utile su macOS, dove la memoria libera è
	//                        quasi sempre poca per costruzione;
	//  · `purgeable_count` — quelle che il sistema può buttare via e basta.
	// Non si conta `external_page_count`: quelle stanno già dentro le attive e
	// le inattive, e sommarle vorrebbe dire contarle due volte — cioè
	// dichiarare più memoria di quanta ce ne sia, che è il verso sbagliato
	// dell'errore.
	mach_port_t host = mach_host_self();
	vm_size_t pagina = 0;
	if (host_page_size(host, &pagina) != KERN_SUCCESS || pagina == 0) {
		return 0;
	}
	vm_statistics64_data_t vm;
	mach_msg_type_number_t quanti = HOST_VM_INFO64_COUNT;
	if (host_statistics64(host, HOST_VM_INFO64,
				reinterpret_cast<host_info64_t>(&vm), &quanti) != KERN_SUCCESS) {
		return 0;
	}
	const uint64_t pagine = static_cast<uint64_t>(vm.free_count) +
			static_cast<uint64_t>(vm.inactive_count) +
			static_cast<uint64_t>(vm.purgeable_count);
	return pagine * static_cast<uint64_t>(pagina);
#elif defined(_WIN32)
	// `ullAvailPhys` è già la risposta giusta: quanta memoria fisica si può
	// prendere senza far cominciare lo swap.
	MEMORYSTATUSEX s;
	s.dwLength = sizeof(s);
	if (!GlobalMemoryStatusEx(&s)) {
		return 0;
	}
	return static_cast<uint64_t>(s.ullAvailPhys);
#elif defined(__linux__)
	// `MemAvailable` è la stima del kernel — la stessa somma che faremmo noi,
	// fatta da chi conosce le sue liste. Se manca (kernel antichi) si torna
	// a MemFree, che sottostima: il verso giusto.
	std::FILE *f = std::fopen("/proc/meminfo", "r");
	if (f == nullptr) {
		return 0;
	}
	char riga[256];
	uint64_t disponibile = 0, libera = 0;
	while (std::fgets(riga, sizeof(riga), f) != nullptr) {
		if (std::strncmp(riga, "MemAvailable:", 13) == 0) {
			disponibile = std::strtoull(riga + 13, nullptr, 10);
			break;
		}
		if (std::strncmp(riga, "MemFree:", 8) == 0) {
			libera = std::strtoull(riga + 8, nullptr, 10);
		}
	}
	std::fclose(f);
	return (disponibile > 0 ? disponibile : libera) * 1024ull;
#else
	return 0;
#endif
}

} // namespace chibi
