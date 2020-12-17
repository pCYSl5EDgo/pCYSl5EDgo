import { promise as lz4promise } from './messagepack_lz4.js';
const testFunction = async (blob) => {
    const lz4 = await lz4promise;
    const originalBytes = new Uint8Array(await blob.arrayBuffer());
    const compressedBytes = lz4.compress(originalBytes);
    if (compressedBytes instanceof Error)
        return compressedBytes;
    console.log("compression currenlty passes");
    const copyCompressed = new Uint8Array(compressedBytes.byteLength);
    copyCompressed.set(compressedBytes);
    const restore = lz4.decompress(copyCompressed, originalBytes.byteLength);
    if (restore instanceof Error) {
        return restore;
    }
    const copyDecompressed = new Uint8Array(restore.byteLength);
    copyDecompressed.set(restore);
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
window.addEventListener("DOMContentLoaded", async () => {
    console.log("loaded");
    const byteLengthInput = document.getElementById("file-bytelength");
    if (!byteLengthInput) {
        throw new Error("file-bytelength not found!");
    }
    const fileInput = document.getElementById("file-input");
    if (!fileInput) {
        throw new Error("file-input not found!");
    }
    const compressedFileList = document.getElementById("compressed-file-list");
    if (!compressedFileList) {
        throw new Error("compressed file list not found!");
    }
    const decompressedFileList = document.getElementById("decompressed-file-list");
    if (!decompressedFileList) {
        throw new Error("decompressed file list not found!");
    }
    const itemTemplate = document.getElementById("template-compress");
    if (!itemTemplate) {
        throw new Error("template not found!");
    }
    const compressButton = document.getElementById("file-compress");
    if (!compressButton) {
        throw new Error("compress button not found!");
    }
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
