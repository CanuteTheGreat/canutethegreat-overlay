// Replacement for vendor/github.com/jacobsa/fuse/internal/buffer/runtime.go (package ctg build):
// the upstream versions jump into runtime internals from assembly, which current Go refuses on arm64.
package buffer

import "unsafe"

// Zero the n bytes starting at p.
func memclr(p unsafe.Pointer, n uintptr) {
	b := unsafe.Slice((*byte)(p), n)
	for i := range b {
		b[i] = 0
	}
}

// Copy from src to dst, allowing overlap.
func memmove(dst unsafe.Pointer, src unsafe.Pointer, n uintptr) {
	copy(unsafe.Slice((*byte)(dst), n), unsafe.Slice((*byte)(src), n))
}
