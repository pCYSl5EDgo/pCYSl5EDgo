export class MessagePackLz4 {
    constructor(instance) {
        this.offset = instance.exports.sourceOffset;
        this.memory = instance.exports.mainMemory;
        this.innerCalcCompressMaximumOutputLength = instance.exports.calcCompressMaximumOutputLength;
        this.innerCompress = instance.exports.compress;
        this.innerDecompress = instance.exports.decompress;
    }
    prepareCompress(sourceLength) {
        const destinationLength = this.innerCalcCompressMaximumOutputLength(sourceLength);
        const neededPage = (sourceLength + destinationLength + this.offset + 0xffff) >> 16;
        const currentPage = (this.memory.buffer.byteLength >> 16);
        const deltaPage = neededPage - currentPage;
        if (deltaPage > 0) {
            if (this.memory.grow(deltaPage) < 0) {
                return new Error("malloc failed! current: " + currentPage.toString() + ", needed: " + neededPage.toString());
            }
        }
        return new Uint8Array(this.memory.buffer, this.offset, sourceLength);
    }
    executeCompress(sourceLength) {
        const destinationLength = this.innerCalcCompressMaximumOutputLength(sourceLength);
        const actual = this.innerCompress(sourceLength, destinationLength);
        return new Uint8Array(this.memory.buffer, this.offset + sourceLength, actual);
    }
    prepareDecompress(sourceLength, destinationLength) {
        const neededPage = (sourceLength + destinationLength + this.offset + 0xffff) >> 16;
        const currentPage = (this.memory.buffer.byteLength >> 16);
        const deltaPage = neededPage - currentPage;
        if (deltaPage > 0) {
            if (this.memory.grow(deltaPage) < 0) {
                return new Error("malloc failed! current: " + currentPage.toString() + ", needed: " + neededPage.toString());
            }
        }
        return new Uint8Array(this.memory.buffer, this.offset, sourceLength);
    }
    executeDecompress(sourceLength, destinationLength) {
        const actual = this.innerDecompress(sourceLength, destinationLength);
        if (actual < 0) {
            return new Error("decompression failed! code: " + actual.toString());
        }
        if (actual != sourceLength) {
            return new Error("decompression failed! src code is not fulley used! source length: " + sourceLength.toString() + ", used : " + actual.toString());
        }
        return new Uint8Array(this.memory.buffer, this.offset + sourceLength, destinationLength);
    }
}
let compileJob;
let instanceJob;
const fetchJob = fetch("./messagepack_lz4.wasm");
if (WebAssembly.instantiateStreaming) {
    const instantiateJob = WebAssembly.instantiateStreaming(fetchJob);
    compileJob = instantiateJob.then(pair => pair.module);
    instanceJob = instantiateJob.then(pair => pair.instance).then(instance => new MessagePackLz4(instance));
}
else {
    compileJob = fetchJob.then(response => response.arrayBuffer()).then(buffer => WebAssembly.compile(buffer));
    instanceJob = compileJob.then(module => WebAssembly.instantiate(module)).then(instance => new MessagePackLz4(instance));
}
export const promise = instanceJob;
export const modulePromise = compileJob;
