#include "llm_memoria.h"

#if defined(__APPLE__)
#include <mach/mach.h>
#include <mach/task_info.h>
#elif defined(__linux__)
#include <cstdio>
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

} // namespace chibi
