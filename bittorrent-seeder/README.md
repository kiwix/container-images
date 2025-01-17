# Kiwix Seeder

`kiwix-seeder` is a simple tool that allows one to manage a Bittorrent seeder for Kiwix Catalog's ZIMs effortlessly.

It 	consists of a script that runs periodically and which consists mostly of:

- Downloading the Kiwix OPDS Catalog
- Matching its entries with your defined filters
- Communicates with your qBittorrent instance (via HTTP)
  - Removes out-of-date (dropped from Catalog) ZIMs from qBittorrent
  - Adds new matching ZIM to qBittorrent

**Key features:**

- Very easy to use
- Very flexible filters so you can precisely select what to seed
- Compatible with your existing qBittorrent (doesnt mess with your stuff)

## Usage

```sh
kiwix-seeder --lang bam --max-storage 1GB
```

## Installation

There are two main ways to use it; choose what's best for you:

| Mode | Target | Reason |
| ---  | -------| --- |
| Standalone Binary | If you already have a running qBittorrent instance. | Lightweight and flexible |
| Docker Image      | All in one docker image that runs both the script and qBittorrent. | Simplest  |

The Docker version obviously depends on Docker being installed and running but

### Docker version

This version is intended for those who want a turn-key solution. It comes with qbittorrent.

### Standalone binary

Simply download and invoke it

```sh
curl -o 
```

#### qBittorrent configuration

`kiwix-seeder` communicates