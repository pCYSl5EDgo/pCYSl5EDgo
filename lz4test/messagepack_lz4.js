const loadWasm = async () => {
    const fetchJob = fetch("./messagepack_lz4.wasm");
    if (WebAssembly.instantiateStreaming) {
        const instance = await WebAssembly.instantiateStreaming(fetchJob);
        return new MessagePackLz4(instance.instance);
    }
    else {
        const response = await fetchJob;
        const bufferResource = await response.arrayBuffer();
        const compiledModule = await WebAssembly.compile(bufferResource);
        const instance = await WebAssembly.instantiate(compiledModule);
        return new MessagePackLz4(instance);
    }
};
export class MessagePackLz4 {
    constructor(instance) {
        this.offset = instance.exports.sourceOffset;
        this.memory = instance.exports.mainMemory;
        this.innerCalcCompressMaximumOutputLength = instance.exports.calcCompressMaximumOutputLength;
        this.innerCompress = instance.exports.compress;
        this.innerDecompress = instance.exports.decompress;
    }
    compress(view) {
        const srcLen = view.length;
        const destinationLength = this.innerCalcCompressMaximumOutputLength(srcLen);
        const neededPage = (srcLen + destinationLength + this.offset + 0xffff) >> 16;
        const currentPage = (this.memory.buffer.byteLength >> 16);
        const deltaPage = neededPage - currentPage;
        if (deltaPage > 0) {
            if (this.memory.grow(deltaPage) < 0) {
                return new Error("malloc failed! current: " + currentPage.toString() + ", needed: " + neededPage.toString());
            }
        }
        const buffer = this.memory.buffer;
        const input = new Uint8Array(buffer, this.offset, srcLen);
        input.set(view);
        const actual = this.innerCompress(srcLen, destinationLength);
        return new Uint8Array(buffer, this.offset + srcLen, actual);
    }
    decompress(view, destinationLength) {
        const srcLen = view.length;
        const neededPage = (srcLen + destinationLength + this.offset + 0xffff) >> 16;
        const currentPage = (this.memory.buffer.byteLength >> 16);
        const deltaPage = neededPage - currentPage;
        if (deltaPage > 0) {
            if (this.memory.grow(deltaPage) < 0) {
                return new Error("malloc failed! current: " + currentPage.toString() + ", needed: " + neededPage.toString());
            }
        }
        const buffer = this.memory.buffer;
        const input = new Uint8Array(buffer, this.offset, srcLen);
        input.set(view);
        const actual = this.innerDecompress(srcLen, destinationLength);
        if (actual < 0) {
            return new Error("decompression failed! code: " + actual.toString());
        }
        if (actual != srcLen) {
            return new Error("decompression failed! src code is not fulley used! source length: " + srcLen.toString() + ", used : " + actual.toString());
        }
        return new Uint8Array(buffer, this.offset + srcLen, actual);
    }
}
export const promise = loadWasm();
