import { promise as lz4promise } from './messagepack_lz4.js';
const testFunction = async (blob) => {
    const lz4 = await lz4promise;
    const originalBytes = new Uint8Array(await blob.arrayBuffer());
    const tempCompressSourceBuffer = lz4.prepareCompress(originalBytes.byteLength);
    if (tempCompressSourceBuffer instanceof Error) {
        return tempCompressSourceBuffer;
    }
    tempCompressSourceBuffer.set(originalBytes);
    const compressedBytes = lz4.executeCompress(originalBytes.byteLength);
    if (compressedBytes instanceof Error) {
        return compressedBytes;
    }
    console.log("compression currenlty passes");
    const copyCompressed = compressedBytes.slice();
    const tempDecompressSourceBuffer = lz4.prepareDecompress(copyCompressed.byteLength, originalBytes.byteLength);
    if (tempDecompressSourceBuffer instanceof Error) {
        return tempDecompressSourceBuffer;
    }
    tempDecompressSourceBuffer.set(copyCompressed);
    const restore = lz4.executeDecompress(copyCompressed.byteLength, originalBytes.byteLength);
    if (restore instanceof Error) {
        return restore;
    }
    const copyDecompressed = restore.slice();
    if (copyDecompressed.length !== originalBytes.length) {
        return new Error("different length. Original : " + originalBytes.length.toString() + ", decompressed : " + copyDecompressed.length.toString());
    }
    for (let index = 0; index < copyDecompressed.length; index++) {
        const element = copyDecompressed[index];
        const rightElement = originalBytes[index];
        if (element != rightElement) {
            return new Error("different element at " + index.toString());
        }
    }
    console.log("decompression success!!!!");
    return {
        compressed: copyCompressed,
        decompressed: copyDecompressed,
    };
};
function getElementById(id) {
    const element = document.getElementById(id);
    if (!element) {
        throw new Error(id + " not found!");
    }
    return element;
}
window.addEventListener("DOMContentLoaded", async () => {
    console.log("loaded");
    const fileInput = getElementById("file-input");
    const compressedFileList = getElementById("compressed-file-list");
    const decompressedFileList = getElementById("decompressed-file-list");
    const itemTemplate = getElementById("template-compress");
    const compressButton = getElementById("file-compress");
    const compressClick = async () => {
        console.log("clocked");
        const files = fileInput.files;
        if (!files || files.length === 0) {
            console.log("empty files");
            return;
        }
        const lz4 = await lz4promise;
        console.log(lz4.offset + " is offset");
        const getBufferJob = [];
        for (let index = 0; index < files.length; index++) {
            const file = files.item(index);
            if (!file || file.size === 0) {
                console.log("file empty continue;");
                continue;
            }
            console.log("file size : " + file.size.toString());
            const job = (async () => {
                const buffer = await file.arrayBuffer();
                console.log("buffer size" + buffer.byteLength.toString());
                const binary = await testFunction(file);
                if (binary instanceof Error) {
                    throw binary;
                }
                console.log("comp + " + binary.compressed.length.toString() + ", decomp + " + binary.decompressed.length.toString() + "\nname : " + file.name);
                return {
                    name: file.name,
                    compressed: new Blob([binary.compressed]),
                    decompressed: new Blob([binary.decompressed]),
                };
            })();
            getBufferJob.push(job);
        }
        console.log("jobs count:" + getBufferJob.length.toString());
        const buffers = await Promise.allSettled(getBufferJob);
        for (const buffer of buffers) {
            if (buffer.status === "fulfilled") {
                const value = buffer.value;
                if (!value)
                    continue;
                {
                    const copy = itemTemplate.content.cloneNode(true);
                    const liElement = copy.querySelector("li");
                    if (!liElement) {
                        throw new Error("not li");
                    }
                    const anchorElement = liElement.querySelector("a");
                    if (!anchorElement) {
                        throw new Error("not anchor");
                    }
                    anchorElement.textContent = value.name + ".lz4";
                    anchorElement.href = URL.createObjectURL(value.compressed);
                    compressedFileList.appendChild(copy);
                }
                {
                    const copy = itemTemplate.content.cloneNode(true);
                    const liElement = copy.querySelector("li");
                    if (!liElement) {
                        throw new Error("not li");
                    }
                    const anchorElement = liElement.querySelector("a");
                    if (!anchorElement) {
                        throw new Error("not anchor");
                    }
                    anchorElement.textContent = value.name;
                    anchorElement.href = URL.createObjectURL(value.decompressed);
                    decompressedFileList.appendChild(copy);
                }
            }
            else if (buffer.status === "rejected") {
                console.log("rejected" + buffer.reason);
            }
        }
    };
    compressButton.addEventListener("click", compressClick);
});
